create or replace PACKAGE BODY      ttec_spain_pay_interface_pkg
AS
--------------------------------------------------------------------
--                                                                --
--     Name:  ttech_spain_pay_inteface_pkg       (Package)              --
--                                                                --
--     Description:   Spain HR Data to the Payroll Vendor     --
--                                       --
--                                                                --
--                                                                --
--     Change History                                             --
--                                                                --
--     Changed By        Date        Reason for Change            --
--     ----------        ----        -----------------            --
--     Dibyendu Roy   22-MAr-2005  Initial Creation For SPAIN    --
--                                                                --
--
--     C.Chan         14-SEP-2005  WO#130327
--                                 Add Fecha de fin de Contrato Prevista have to be populated with
--                                 proposed End Date, from the contrct form. Also rearrange the
--                                 sequence of the fields
--
--                                 The problem is with the last 4 fields of the record. In the current
--                                 layout, that last 4 fields are:
--
--                                 52 - Banco Emisor
--                                 53 - Job Code
--                                 54 - Fecha Inicio Bonificacion
--                                 55 - Fecha Fin Bonificacion
--                                 The correct layout have to be:
--                                 52 - Banco Emisor
--                                 53 - Fecha de Fin de Contrato Prevista
--                                 54 - Fecha Inicio Bonificacion
--                                 55 - Fecha Fin Bonificacion
--                                 56 - Job Code
--                                 The field 53 - Fecha de Fin de Contrato Prevista have to be populated
--                                 with the Proposed End Date, from the Contract form.
--
--     C.Chan         21-SEP-2005  WO#131875
--                                 new field (for marital status) was added in the Meta4 layout at the end
--                                 of both the NAEA (field 58) and the NAEN (field 75) sections. This field
--                                 have to be populated with a value of 2 numeric characters according to
--                                 the following mapping table:
--
--                                 01   Soltero/a
--                                 02   Casado/a
--                                 03   Viudo/a
--                                 04   Divorciado/a
--                                 05   Pareja de hecho
--                                 06   Separado/a
--
--     C.Chan         22-SEP-2005  WO#131255 NAEA records are being duplicated
--
--     C.Chan         23-SEP-2005  WO#130329 Termination/rehing in the same day not pulling NAEA and NBE records
--
--     C.Chan         23-SEP-2005  WO#130330 MDP records are being duplicated
--
--     C.Chan         23-SEP-2005  WO#133137 NAEN records field #31 "Fecha Fin Prevista" has no value, have to be
--                                 populated with Per_contract_f.CTR_Information4
--
--     C.Chan         30-SEP-2005  WO#131247 - Bank data changes not showing in the HR interface
--
--     C.Chan         27-OCT-2005  TT#421375 - Picking up old bank info, not sending new bank info
--
--     C.Chan         27-OCT-2005  WO#130335 - MAP records field #13 Need to show proposed End of Contract date instead of contract end date
--
--     C.Chan         31-OCT-2005  WO#130335  - Matias feedback requested that MAP records field #11 needs to be "Fecha Fin Prevista"  instead of NULL
--                                              and field # 14 needs to be NULL instead of "Fecha Fin Periodo"
--
--     C.Chan         17-NOV-2005  TT#427856 - Some employee were rehired but not picking up in the interface (EX-EMP causes to fail. Should be EX_EMP)
--
--     C.Chan         21/DEC-2005  WO#144030 - Add 2 new fields in NAEA and NAEN sections (Telephone number 1 and 2 from address from at the end of each sections.
--
--     C.Chan         21/DEC-2005  WO#147293 - Add 2 new fields in MAP section. Contract Extension Start Date and Contract Extension End Date
--
--     C.Chan         21/DEC-2005  WO#150091 - Add Fecha Nofificacion (Notified Termination Date) to NBE section.
--                                           - Add Fecha de Incorporacion (per_all_people_f.attribute19) to NAEA section.
--     C.Chan         22-DEC-2005  TT#444301 - Some employee were rehired but not picking up in the interface (EX-EMP causes to fail. Should be EX_EMP)
--
--     C.Chan         22-DEC-2005  TT#411517 - Spain's user tried to generate the daily extract in Spanish language (like usually do) and the process returned an error.
--
--     C.Chan         01-FEB-2006  TT#456121  - Add new procedure to baseline the interface tables
--
--     C.Chan         03-FEB-2006  WO#163242  - Spain HR/Payroll extract have to picks up all employees with Legacy Number.
--
----------------------------------------------------------------------------------------------------------
--     C.Chan         16-MAR-2006  WO#163242  - Spain HR extract MAP sections feedback from MAtias
---------------------------------------------------------------------------------------------------------
--, iv_field13            => r_emp.Fecha_fin_prevista  -- C. Chan Oct 27,WO# 130335 Need to show proposed End of Contract date  instead of contract end date
--This field should be populated with Contract End Date. In the WO#130335 I mentioned that the contract end date is not being picked up when it was changed, not to change it to the proposed end date.
--
--, iv_field31            => NULL
--This field should be populated with the date of change, just when field 32 is populated.
--
--, iv_field50            => r_emp.FECHA_INICIO_CONT_ESPECíFICO  -- WO#147293 By C. Chan 12/22/05 Matias email requested this to be mandatory
--, iv_field51            => r_emp.Fecha_fin_prevista                           -- WO#147293 By C. Chan 12/22/05 Matias email requested this to be mandatory
--
--These fields should be populated just when the contract end date is not null, and following the criteria mentioned in the WO and repeated below.
--
--The contract period extension must be informed with two consecutives MAP sections in the HR interface. In example, if the employee 121640 has an end of contract for 2005-09-30, and a contract extension period from 2005-10-01 to 2005-10-30, HR interface should be like this:
--
--MAP;121640;1;;;;;;2005-09-26;;;;2005-09-30;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
--MAP;121640;1;;;;;;2005-09-26;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;2005-10-01;2005-10-30
--
--So, fields 50 and 51 should be populated with:
--
--         Contract extension start date (50): the following date of the contract end date
--
--         Contract extension end date (51): proposed end date
--
----------------------------------------------------------------------------------------------------------
--
----------------------------------------------------------------------------------------------------------
--     C.Chan         29-May-2006         Oracle code 2230 to Meta4 code 35 per Matias email dated May 19,2006
--
--     C.Chan         06-Jul-2006         WO#200196: the MAP record populates the field 41 (Fecha Inicio tipo IRPF) even
--                                        when the IRPF value has not changed. Add NVL on the IF statement
--
--     C.Chan         06-Jul-2006         When inserting a baseline data (cut of date - 1), do not generate output
--
--     C.Chan         12-Jul-2006         WO#207372 - Adding costing information to MAR section field#16
--
--     C.Chan         19-Jul-2006         WO#208732 - There is a modification needed for the MDD section. The fields #7-8-9 (Country-Province-Postal Code) must be mandatory, so they must be populated even though they were not modified.
--
--     C.Chan         30-AUG-2006         WO#208732 - Add DISABILITY to NAEN, NAEA and MDP sections. Must be with capital letters
--
--     C.Chan         14-DEC-2006         WO#256205  - MAP record populates the field 41 (Fecha Inicio tipo IRPF) even when the IRPF value has not changed.
--
--     C.Chan         14-DEC-2006         TT#615375  - NAEN record is generating the employee cost center incorrectly for some employees. The employee has 010 in his Organization and the interface is showing 005.
--
--     C.Chan         08-AUG-2007         WO#293166  - New translation table needed during the interface process on centro_de_trabajo
--
--     C.Chan         25-SEP-2007         WO#293166  - email from Victor - a new location named ¿ESP-ESPAÑA¿ is added The WC code will be ¿1¿,
--                                                            the same of ¿ESP-BARCELONA (AVI)¿.
--
--     C.Chan         01-APR-2008         WO#431198  - Created DFF to map to META4 LEAV_REAS valid code. DFF title -> Common lookup New Field -> Payroll Mapping (ATTRIBUTE4)
--
--     C.Chan         13-JUN-2008         TT#965056  - New Location was added. Need to reflect ESP-Barcelona (Badajoz)
--                                                     The attribute 2 for all cases is: '04211'->need this location to transmitt '36' as a work center code to the interface
--
--     C.Chan         12-MAR-2009         TT#570394  - New Location was added. Need to reflect E ESP-At Home
--                                                     The attribute 2 for all cases is: '04226'->need this location to transmitt '37' as a work center code to the interface
--                                                     Also cleanup all old PROCEDURES
--
--     C.Chan         23-APR-2009         WO#585359 - to hard code the new SPN Empresa ID 'TeleTech Spain @Home - 10325' with the Meta4 code '19' that will show in the extract.
--
--     C.Chan         28-MAY-2009         WO#598085 - MDB Record change on field #9 - replace Banco_emisor with legal_employer
--
--
--     C.Chan         10-Jun-2009         WO#602234 - translate the work center code for ESP-@Home Madrid so that it can be entered in Meta4 with code 38
--
--     C.Chan         11-Aug-2009         WO#621742 - translate the work center code for ESP-@Home Oviedo so that it can be entered in Meta4 with code 39
--
-- 1.0 C.Chan         12-OCT-2010          TTEC R#332905 - LEAVE OF ABSENCE FOR SPAIN (EXCEDENCIA)
-- 1.1 C.Chan         09-AUG-2011          TTSD I#871773 - Modify the logic to send NBE movement future Termination on EXCEDENCIA
-- 1.0 RXNETHI-ARGANO 16-MAY-2023          R12.2 Upgrade Remediatino
--------------------------------------------------------------------
   PROCEDURE print_line (iv_data IN VARCHAR2)
   IS
   BEGIN
      fnd_file.put_line (fnd_file.output, iv_data || ';');
   --Fnd_File.put_line(Fnd_File.LOG,iv_data || ';');
   END;                                                          -- print_line

   FUNCTION scrub_to_number (iv_text IN VARCHAR2)
      RETURN VARCHAR2
   IS
      v_number   VARCHAR2 (255);
      v_length   NUMBER;
      i          NUMBER;
   BEGIN
      v_length := LENGTH (iv_text);

      IF v_length > 0
      THEN
         -- look at each character in text and remove any non-numbers
         FOR i IN 1 .. v_length
         LOOP
            IF ASCII (SUBSTR (iv_text, i, 1)) BETWEEN 48 AND 57
            THEN
               v_number := v_number || SUBSTR (iv_text, i, 1);
            END IF;                                 -- ascii between 48 and 57
         END LOOP;                                                        -- i
      END IF;                                                      -- v_length

      RETURN v_number;
   EXCEPTION
      WHEN OTHERS
      THEN
         RETURN iv_text;
   END;                                            -- function scrub_to_number

   PROCEDURE set_business_group_id (
      iv_business_group   IN   VARCHAR2 DEFAULT 'TeleTech Holdings - ESP'
   )
   IS
   BEGIN
      SELECT organization_id
        INTO g_business_group_id
        FROM hr_all_organization_units
       WHERE NAME = iv_business_group;
   EXCEPTION
      WHEN OTHERS
      THEN
         fnd_file.put_line (fnd_file.LOG
                          , 'Unable to Determine Business Group ID'
                           );
         fnd_file.put_line (fnd_file.LOG, SUBSTR (SQLERRM, 1, 255));
         g_errbuf := SUBSTR (SQLERRM, 1, 255);
         g_retcode := SQLCODE;
         RAISE g_e_abort;
   END;                                     -- procedure set_business_group_id

   FUNCTION pad_data_output (
      iv_field_type    IN   VARCHAR2
    , iv_pad_length    IN   NUMBER
    , iv_field_value   IN   VARCHAR2
   )
      RETURN VARCHAR2
   IS
      v_length_var    NUMBER;
      v_varchar_pad   VARCHAR2 (1) := ' ';
      v_number_pad    VARCHAR2 (1) := ' ';
      v_length_diff   NUMBER       := 0;
   BEGIN
      /*IF UPPER(iv_field_type) = 'VARCHAR2' AND iv_pad_length > 0 --and iv_field_value is not null
        THEN
           RETURN SUBSTRB(RPAD( NVL(iv_field_value,' '), iv_pad_length, v_varchar_pad ),1,iv_pad_length);
        ELSIF  UPPER(iv_field_type) = 'NUMBER' AND iv_pad_length > 0 --AND iv_field_value IS NOT NULL
         THEN
            RETURN LPAD( iv_field_value, iv_pad_length, v_number_pad );
      END IF;
      EXCEPTION
        WHEN OTHERS THEN
          RETURN NULL;*/
      IF     UPPER (iv_field_type) = 'VARCHAR2'
         AND iv_pad_length > 0                --and iv_field_value is not null
      THEN
         RETURN LTRIM (RTRIM (NVL (iv_field_value, ' ')));
      ELSIF     UPPER (iv_field_type) = 'NUMBER'
            AND iv_pad_length > 0             --AND iv_field_value IS NOT NULL
      THEN
         RETURN LPAD (iv_field_value, iv_pad_length, v_number_pad);
      END IF;
   EXCEPTION
      WHEN OTHERS
      THEN
         RETURN NULL;
   END;                                           -- Function  pad_data_output

   PROCEDURE insert_interface_pps (
      --ir_interface_pps   cust.ttec_spain_pay_interface_pps%ROWTYPE  --code commented by RXNETHI-ARGANO,16/05/23
      ir_interface_pps   apps.ttec_spain_pay_interface_pps%ROWTYPE    --code added by RXNETHI-ARGANO,16/05/23
   )
   IS
   BEGIN
      --INSERT INTO cust.ttec_spain_pay_interface_pps  --code commented by RXNETHI-ARGANO,16/05/23
      INSERT INTO apps.ttec_spain_pay_interface_pps    --code added by RXNETHI-ARGANO,16/05/23
                  (period_of_service_id
                 , person_id, date_start
                 , accepted_termination_date
                 , actual_termination_date
                 , final_process_date
                 , last_standard_process_date
                 , leaving_reason
                 , notified_termination_date
                 , projected_termination_date
                 , last_update_date
                 , creation_date
                 , cut_off_date
                 , papf_effective_start_date
                 , papf_effective_end_date
                 , paaf_effective_start_date
                 , paaf_effective_end_date
                 , paaf_assignment_id
                 , extract_date
                  )
           VALUES (ir_interface_pps.period_of_service_id
                 , ir_interface_pps.person_id, ir_interface_pps.date_start
                 , ir_interface_pps.accepted_termination_date
                 , ir_interface_pps.actual_termination_date
                 , ir_interface_pps.final_process_date
                 , ir_interface_pps.last_standard_process_date
                 , ir_interface_pps.leaving_reason
                 , ir_interface_pps.notified_termination_date
                 , ir_interface_pps.projected_termination_date
                 , ir_interface_pps.last_update_date
                 , ir_interface_pps.creation_date
                 , ir_interface_pps.cut_off_date
                 , ir_interface_pps.papf_effective_start_date
                 , ir_interface_pps.papf_effective_end_date
                 , ir_interface_pps.paaf_effective_start_date
                 , ir_interface_pps.paaf_effective_end_date
                 , ir_interface_pps.paaf_assignment_id
                 , ir_interface_pps.extract_date
                  );
   END;                                      -- procedure insert_interface_pps

   PROCEDURE insert_interface_mst (
      --ir_interface_mst   cust.ttec_spain_pay_interface_mst%ROWTYPE  --code commented by RXNETHI-ARGANO,16/05/23
      ir_interface_mst   apps.ttec_spain_pay_interface_mst%ROWTYPE    --code added by RXNETHI-ARGANO,16/05/23
   )
   IS
   BEGIN
      --Fnd_File.put_line(Fnd_File.LOG,'Stage 17');
/*
                                  Fnd_File.put_line(Fnd_File.LOG,'1'||ir_interface_mst.employee_id);
                           Fnd_File.put_line(Fnd_File.LOG,'2'||ir_interface_mst.last_name);
                           Fnd_File.put_line(Fnd_File.LOG,'3'||ir_interface_mst.second_last_name);
                           Fnd_File.put_line(Fnd_File.LOG,'4'||ir_interface_mst.first_name);
                           Fnd_File.put_line(Fnd_File.LOG,'5'||ir_interface_mst.birth_date);
                           Fnd_File.put_line(Fnd_File.LOG,'6'||ir_interface_mst.gender);
                           Fnd_File.put_line(Fnd_File.LOG,'7'||ir_interface_mst.treatment);
                           Fnd_File.put_line(Fnd_File.LOG,'8'||ir_interface_mst.nationality);
                           Fnd_File.put_line(Fnd_File.LOG,'9'||ir_interface_mst.nif_value);
                           Fnd_File.put_line(Fnd_File.LOG,'10'||ir_interface_mst.nie);
                           Fnd_File.put_line(Fnd_File.LOG,'11'||ir_interface_mst.numero_s_social);
                           Fnd_File.put_line(Fnd_File.LOG,'12'||ir_interface_mst.irpf);
                           Fnd_File.put_line(Fnd_File.LOG,'13'||ir_interface_mst.id_direccion);
                           Fnd_File.put_line(Fnd_File.LOG,'14'||ir_interface_mst.address_line1);
                           Fnd_File.put_line(Fnd_File.LOG,'15'||ir_interface_mst.address_line2);
                           Fnd_File.put_line(Fnd_File.LOG,'16'||ir_interface_mst.country);
                           Fnd_File.put_line(Fnd_File.LOG,'17'||ir_interface_mst.region_1);
                           Fnd_File.put_line(Fnd_File.LOG,'18'||ir_interface_mst.postal_code);
                           Fnd_File.put_line(Fnd_File.LOG,'19'||ir_interface_mst.address_line3);
                           Fnd_File.put_line(Fnd_File.LOG,'20'||ir_interface_mst.ordinal_periodo);
                           Fnd_File.put_line(Fnd_File.LOG,'21'||ir_interface_mst.ass_eff_date);
                           Fnd_File.put_line(Fnd_File.LOG,'22'||ir_interface_mst.motivo_alta);
                           Fnd_File.put_line(Fnd_File.LOG,'23'||ir_interface_mst.fecha_antiguedad);
                           Fnd_File.put_line(Fnd_File.LOG,'24'||ir_interface_mst.fecha_extra);
                           Fnd_File.put_line(Fnd_File.LOG,'25'||ir_interface_mst.tipo_empleado);
                           Fnd_File.put_line(Fnd_File.LOG,'26'||ir_interface_mst.pago_gestiontiempo);
                           Fnd_File.put_line(Fnd_File.LOG,'27'||ir_interface_mst.modelo_de_referencia);
                           Fnd_File.put_line(Fnd_File.LOG,'28'||ir_interface_mst.legal_employer);
                           Fnd_File.put_line(Fnd_File.LOG,'29'||ir_interface_mst.id_contrato_interno);
                           Fnd_File.put_line(Fnd_File.LOG,'30'||ir_interface_mst.Fecha_fin_prevista);
                           Fnd_File.put_line(Fnd_File.LOG,'31'||ir_interface_mst.Fecha_fin_periodo);
                           Fnd_File.put_line(Fnd_File.LOG,'32'||ir_interface_mst.Fecha_fin_contrato);
                           Fnd_File.put_line(Fnd_File.LOG,'33'||ir_interface_mst.Clausulas_adicionales);
                           Fnd_File.put_line(Fnd_File.LOG,'34'||ir_interface_mst.Condicion_desempleado);
                           Fnd_File.put_line(Fnd_File.LOG,'35'||ir_interface_mst.Relacion_laboral_especial);
                           Fnd_File.put_line(Fnd_File.LOG,'36'||ir_interface_mst.Causa_sustitucion);
                           Fnd_File.put_line(Fnd_File.LOG,'37'||ir_interface_mst.Mujer_subrepresentda);
                           Fnd_File.put_line(Fnd_File.LOG,'38'||ir_interface_mst.Incapacitado_readmitido);
                           Fnd_File.put_line(Fnd_File.LOG,'39'||ir_interface_mst.Primer_trabajador_autonomo);
                           Fnd_File.put_line(Fnd_File.LOG,'40'||ir_interface_mst.Exclusion_social);
                           Fnd_File.put_line(Fnd_File.LOG,'41'||ir_interface_mst.Fecha_inicio_cont_específico);
                           Fnd_File.put_line(Fnd_File.LOG,'42'||ir_interface_mst.FIC_especifico);
                           Fnd_File.put_line(Fnd_File.LOG,'43'||ir_interface_mst.Numero_SS_sustituido);
                           Fnd_File.put_line(Fnd_File.LOG,'44'||ir_interface_mst.Renta_active_insercion);
                           Fnd_File.put_line(Fnd_File.LOG,'45'||ir_interface_mst.Mujer_mater_24_meses);
                           Fnd_File.put_line(Fnd_File.LOG,'46'||ir_interface_mst.Mantiene_contrato_legal);
                           Fnd_File.put_line(Fnd_File.LOG,'47'||ir_interface_mst.Contrato_relevo);
                           Fnd_File.put_line(Fnd_File.LOG,'48'||ir_interface_mst.Mujer_reincorporada);
                           Fnd_File.put_line(Fnd_File.LOG,'49'||ir_interface_mst.Excluido_fichero_AFI);
                           Fnd_File.put_line(Fnd_File.LOG,'50'||ir_interface_mst.normal_hours);
                           Fnd_File.put_line(Fnd_File.LOG,'51'||ir_interface_mst.work_center);
                           Fnd_File.put_line(Fnd_File.LOG,'52'||ir_interface_mst.convenio);
                           Fnd_File.put_line(Fnd_File.LOG,'53'||ir_interface_mst.epigrafe);
                           Fnd_File.put_line(Fnd_File.LOG,'54'||ir_interface_mst.grupo_tarifa);
                           Fnd_File.put_line(Fnd_File.LOG,'55'||ir_interface_mst.clave_percepcion);
                           Fnd_File.put_line(Fnd_File.LOG,'56'||ir_interface_mst.tax_id);
                           Fnd_File.put_line(Fnd_File.LOG,'57'||ir_interface_mst.tipo_salario);
                           Fnd_File.put_line(Fnd_File.LOG,'58'||ir_interface_mst.tipo_de_ajuste);
                           Fnd_File.put_line(Fnd_File.LOG,'59'||ir_interface_mst.job_id);
                            Fnd_File.put_line(Fnd_File.LOG,'60'||ir_interface_mst.new_job_id);
                           Fnd_File.put_line(Fnd_File.LOG,'61'||ir_interface_mst.departmento);
                           Fnd_File.put_line(Fnd_File.LOG,'62'||ir_interface_mst.centro_de_trabajo);
                           Fnd_File.put_line(Fnd_File.LOG,'63'||ir_interface_mst.nivel_salarial);
                           Fnd_File.put_line(Fnd_File.LOG,'64'||ir_interface_mst.centros_de_coste);
                           Fnd_File.put_line(Fnd_File.LOG,'65'||ir_interface_mst.salary);
                           Fnd_File.put_line(Fnd_File.LOG,'66'||ir_interface_mst.bank_name);
                           Fnd_File.put_line(Fnd_File.LOG,'67'||ir_interface_mst.bank_branch);
                           Fnd_File.put_line(Fnd_File.LOG,'68'||ir_interface_mst.account_number);
                           Fnd_File.put_line(Fnd_File.LOG,'69'||ir_interface_mst.control_id);
                           Fnd_File.put_line(Fnd_File.LOG,'70'||ir_interface_mst.tipo_de_pago);
                           Fnd_File.put_line(Fnd_File.LOG,'71'||ir_interface_mst.banco_emisor);
                           Fnd_File.put_line(Fnd_File.LOG,'72'||ir_interface_mst.person_type);
                           Fnd_File.put_line(Fnd_File.LOG,'73'||ir_interface_mst.address_date_start);
                           Fnd_File.put_line(Fnd_File.LOG,'74'||ir_interface_mst.date_start);
                           Fnd_File.put_line(Fnd_File.LOG,'75'||ir_interface_mst.salary_change_date);
                           Fnd_File.put_line(Fnd_File.LOG,'76'||ir_interface_mst.person_creation_date);
                           Fnd_File.put_line(Fnd_File.LOG,'77'||ir_interface_mst.person_update_date);
                           Fnd_File.put_line(Fnd_File.LOG,'78'||ir_interface_mst.assignment_id);
                           Fnd_File.put_line(Fnd_File.LOG,'79'||ir_interface_mst.assignment_creation_date);
                           Fnd_File.put_line(Fnd_File.LOG,'80'||ir_interface_mst.assignment_update_date);
                           Fnd_File.put_line(Fnd_File.LOG,'81'||ir_interface_mst.payroll_id);
                           Fnd_File.put_line(Fnd_File.LOG,'82'||ir_interface_mst.payroll_name);
                           Fnd_File.put_line(Fnd_File.LOG,'83'||ir_interface_mst.person_id);
                           Fnd_File.put_line(Fnd_File.LOG,'84'||ir_interface_mst.party_id);
                           Fnd_File.put_line(Fnd_File.LOG,'85'||ir_interface_mst.person_type_id);
                           Fnd_File.put_line(Fnd_File.LOG,'86'||ir_interface_mst.system_person_type);
                           Fnd_File.put_line(Fnd_File.LOG,'87'||ir_interface_mst.user_person_type);
                           Fnd_File.put_line(Fnd_File.LOG,'88'||ir_interface_mst.period_of_service_id);
                           Fnd_File.put_line(Fnd_File.LOG,'89'||ir_interface_mst.actual_termination_date);
                           Fnd_File.put_line(Fnd_File.LOG,'90'||ir_interface_mst.leaving_reason);
                           Fnd_File.put_line(Fnd_File.LOG,'91'||ir_interface_mst.creation_date);
                           Fnd_File.put_line(Fnd_File.LOG,'92'||ir_interface_mst.last_extract_date);
                           Fnd_File.put_line(Fnd_File.LOG,'93'||ir_interface_mst.last_extract_file_type);
                           Fnd_File.put_line(Fnd_File.LOG,'94'||ir_interface_mst.cut_off_date);
                           Fnd_File.put_line(Fnd_File.LOG,'95'||ir_interface_mst.pppm_effective_date);
                          Fnd_File.put_line(Fnd_File.LOG,'96'||ir_interface_mst.NumeroSSocial_DT);
                          Fnd_File.put_line(Fnd_File.LOG,'97'||ir_interface_mst.IdContratoInterno_DT);
                          Fnd_File.put_line(Fnd_File.LOG,'98'||ir_interface_mst.EpiGrafe_DT);
                          Fnd_File.put_line(Fnd_File.LOG,'99'||ir_interface_mst.ClavePercepcion_DT);
                          Fnd_File.put_line(Fnd_File.LOG,'100'||ir_interface_mst.CostSegment_dt);
                          Fnd_File.put_line(Fnd_File.LOG,'101'||ir_interface_mst.Fecha_Inicio_Bonificacion);
                          Fnd_File.put_line(Fnd_File.LOG,'102'||ir_interface_mst.Fecha_Fin_Bonificacion);
                          Fnd_File.put_line(Fnd_File.LOG,'103'||ir_interface_mst.Marital_status );
                          Fnd_File.put_line(Fnd_File.LOG,'104'||ir_interface_mst.telephone1 );
                          Fnd_File.put_line(Fnd_File.LOG,'105'||ir_interface_mst.telephone2 );
                          Fnd_File.put_line(Fnd_File.LOG,'106'||ir_interface_mst.notified_termination_date );
                          Fnd_File.put_line(Fnd_File.LOG,'107'||ir_interface_mst.fecha_de_incorporacion );
                          Fnd_File.put_line(Fnd_File.LOG,'109'||ir_interface_mst.original_date_of_hire );
*/
      --INSERT INTO cust.ttec_spain_pay_interface_mst  --code commented by RXNETHI-ARGANO,16/05/23
      INSERT INTO apps.ttec_spain_pay_interface_mst    --code added by RXNETHI-ARGANO,16/05/23
                  (employee_id, last_name
                 , second_last_name
                 , first_name, birth_date
                 , gender, treatment
                 , nationality, nif_value
                 , nie, numero_s_social
                 , irpf, id_direccion
                 , address_line1
                 , address_line2, country
                 , region_1, postal_code
                 , address_line3
                 , ordinal_periodo
                 , ass_eff_date
                 , motivo_alta
                 , fecha_antiguedad
                 , fecha_extra
                 , tipo_empleado
                 , pago_gestiontiempo
                 , modelo_de_referencia
                 , legal_employer
                 , id_contrato_interno
                 , fecha_fin_prevista
                 , fecha_fin_periodo
                 , fecha_fin_contrato
                 , clausulas_adicionales
                 , condicion_desempleado
                 , relacion_laboral_especial
                 , causa_sustitucion
                 , mujer_subrepresentda
                 , incapacitado_readmitido
                 , primer_trabajador_autonomo
                 , exclusion_social
                 , fecha_inicio_cont_específico
                 , fic_especifico
                 , numero_ss_sustituido
                 , renta_active_insercion
                 , mujer_mater_24_meses
                 , mantiene_contrato_legal
                 , contrato_relevo
                 , mujer_reincorporada
                 , excluido_fichero_afi
                 , normal_hours
                 , work_center, convenio
                 , epigrafe, grupo_tarifa
                 , clave_percepcion
                 , tax_id, tipo_salario
                 , tipo_de_ajuste, job_id
                 , new_job_id
                 , departmento
                 , centro_de_trabajo
                 , nivel_salarial
                 , centros_de_coste
                 , salary, bank_name
                 , bank_branch
                 , account_number
                 , control_id
                 , tipo_de_pago
                 , banco_emisor
                 , person_type
                 , address_date_start
                 , date_start
                 , salary_change_date
                 , person_creation_date
                 , person_update_date
                 , assignment_id
                 , assignment_creation_date
                 , assignment_update_date
                 , payroll_id
                 , payroll_name
                 , person_id, party_id
                 , person_type_id
                 , system_person_type
                 , user_person_type
                 , period_of_service_id
                 , actual_termination_date
                 , leaving_reason
                 , creation_date
                 , last_extract_date
                 , last_extract_file_type
                 , cut_off_date
                 , pppm_effective_date
                 , numerossocial_dt
                 , idcontratointerno_dt
                 , epigrafe_dt
                 , clavepercepcion_dt
                 , costsegment_dt
                 , fecha_inicio_bonificacion
                 , fecha_fin_bonificacion
                 , marital_status     -- WO#131875  added By C.Chan 09/21/2005
                 , telephone1          -- WO#144030 added By C.Chan 12/21/2005
                 , telephone2          -- WO#144030 added By C.Chan 12/21/2005
                 , notified_termination_date
                                      -- WO#150091  added By C.Chan 12/21/2005
                 , fecha_de_incorporacion
                                      -- WO#150091  added By C.Chan 12/22/2005
                 , original_date_of_hire            -- Added by CC on 3/8/2006
                 , original_contract_end_date       -- added by CC on 4/4/2006
                 , original_contract_start_date     -- added by CC on 4/4/2006
                 , contract_pps_start_date         -- added by CC on 4/13/2006
                 , contract_pps_end_date           -- added by CC on 4/13/2006
                 , contract_update_date
                                      -- added by CC on 4/20/2006 for issue#13
                 , pps_update_date    -- added by CC on 4/20/2006 for issue#13
                 , pcaf_update_date   -- added by CC on 4/20/2006 for issue#13
                 , salary_update_date -- added by CC on 4/20/2006 for issue#13
                 , bank_update_date   -- added by CC on 4/20/2006 for issue#13
                 , address_update_date
                                      -- added by CC on 4/20/2006 for issue#13
                 , contract_active_end_date        -- added by CC on 4/27/2006
                 , costing_pct                     -- added by CC on 7/12/2006
                 , disability          -- Added by C. Chan 8/30/2006 WO#217631
                 , assignment_status                                  -- v 1.0
                  )
           VALUES (ir_interface_mst.employee_id, ir_interface_mst.last_name
                 , ir_interface_mst.second_last_name
                 , ir_interface_mst.first_name, ir_interface_mst.birth_date
                 , ir_interface_mst.gender, ir_interface_mst.treatment
                 , ir_interface_mst.nationality, ir_interface_mst.nif_value
                 , ir_interface_mst.nie, ir_interface_mst.numero_s_social
                 , ir_interface_mst.irpf, ir_interface_mst.id_direccion
                 , ir_interface_mst.address_line1
                 , ir_interface_mst.address_line2, ir_interface_mst.country
                 , ir_interface_mst.region_1, ir_interface_mst.postal_code
                 , ir_interface_mst.address_line3
                 , ir_interface_mst.ordinal_periodo
                 , ir_interface_mst.ass_eff_date
                 , ir_interface_mst.motivo_alta
                 , ir_interface_mst.fecha_antiguedad
                 , ir_interface_mst.fecha_extra
                 , ir_interface_mst.tipo_empleado
                 , ir_interface_mst.pago_gestiontiempo
                 , ir_interface_mst.modelo_de_referencia
                 , ir_interface_mst.legal_employer
                 , ir_interface_mst.id_contrato_interno
                 , ir_interface_mst.fecha_fin_prevista
                 , ir_interface_mst.fecha_fin_periodo
                 , ir_interface_mst.fecha_fin_contrato
                 , ir_interface_mst.clausulas_adicionales
                 , ir_interface_mst.condicion_desempleado
                 , ir_interface_mst.relacion_laboral_especial
                 , ir_interface_mst.causa_sustitucion
                 , ir_interface_mst.mujer_subrepresentda
                 , ir_interface_mst.incapacitado_readmitido
                 , ir_interface_mst.primer_trabajador_autonomo
                 , ir_interface_mst.exclusion_social
                 , ir_interface_mst.fecha_inicio_cont_específico
                 , ir_interface_mst.fic_especifico
                 , ir_interface_mst.numero_ss_sustituido
                 , ir_interface_mst.renta_active_insercion
                 , ir_interface_mst.mujer_mater_24_meses
                 , ir_interface_mst.mantiene_contrato_legal
                 , ir_interface_mst.contrato_relevo
                 , ir_interface_mst.mujer_reincorporada
                 , ir_interface_mst.excluido_fichero_afi
                 , ir_interface_mst.normal_hours
                 , ir_interface_mst.work_center, ir_interface_mst.convenio
                 , ir_interface_mst.epigrafe, ir_interface_mst.grupo_tarifa
                 , ir_interface_mst.clave_percepcion
                 , ir_interface_mst.tax_id, ir_interface_mst.tipo_salario
                 , ir_interface_mst.tipo_de_ajuste, ir_interface_mst.job_id
                 , ir_interface_mst.new_job_id
                 , ir_interface_mst.departmento
                 , ir_interface_mst.centro_de_trabajo
                 , ir_interface_mst.nivel_salarial
                 , ir_interface_mst.centros_de_coste
                 , ir_interface_mst.salary, ir_interface_mst.bank_name
                 , ir_interface_mst.bank_branch
                 , ir_interface_mst.account_number
                 , ir_interface_mst.control_id
                 , ir_interface_mst.tipo_de_pago
                 , ir_interface_mst.banco_emisor
                 , ir_interface_mst.person_type
                 , ir_interface_mst.address_date_start
                 , ir_interface_mst.date_start
                 , ir_interface_mst.salary_change_date
                 , ir_interface_mst.person_creation_date
                 , ir_interface_mst.person_update_date
                 , ir_interface_mst.assignment_id
                 , ir_interface_mst.assignment_creation_date
                 , ir_interface_mst.assignment_update_date
                 , ir_interface_mst.payroll_id
                 , ir_interface_mst.payroll_name
                 , ir_interface_mst.person_id, ir_interface_mst.party_id
                 , ir_interface_mst.person_type_id
                 , ir_interface_mst.system_person_type
                 , ir_interface_mst.user_person_type
                 , ir_interface_mst.period_of_service_id
                 , ir_interface_mst.actual_termination_date
                 , ir_interface_mst.leaving_reason
                 , ir_interface_mst.creation_date
                 , ir_interface_mst.last_extract_date
                 , ir_interface_mst.last_extract_file_type
                 , ir_interface_mst.cut_off_date
                 , ir_interface_mst.pppm_effective_date
                 , ir_interface_mst.numerossocial_dt
                 , ir_interface_mst.idcontratointerno_dt
                 , ir_interface_mst.epigrafe_dt
                 , ir_interface_mst.clavepercepcion_dt
                 , ir_interface_mst.costsegment_dt
                 , ir_interface_mst.fecha_inicio_bonificacion
                 , ir_interface_mst.fecha_fin_bonificacion
                 , ir_interface_mst.marital_status
                                      -- WO#131875  added By C.Chan 09/21/2005
                 , ir_interface_mst.telephone1
                                       -- WO#144030 added By C.Chan 12/21/2005
                 , ir_interface_mst.telephone2
                                       -- WO#144030 added By C.Chan 12/21/2005
                 , ir_interface_mst.notified_termination_date
                                      -- WO#150091  added By C.Chan 12/21/2005
                 , ir_interface_mst.fecha_de_incorporacion
                                      -- WO#150091  added By C.Chan 12/21/2005
                 , ir_interface_mst.original_date_of_hire
                                                    -- Added by CC on 3/8/2006
                 , ir_interface_mst.original_contract_end_date
                                                    -- Added by CC on 4/4/2006
                 , ir_interface_mst.original_contract_start_date
                                                    -- Added by CC on 4/4/2006
                 , ir_interface_mst.contract_pps_start_date
                                                   -- added by CC on 4/13/2006
                 , ir_interface_mst.contract_pps_end_date
                                                   -- added by CC on 4/13/2006
                 , ir_interface_mst.contract_update_date
                                      -- added by CC on 4/20/2006 for issue#13
                 , ir_interface_mst.pps_update_date
                                      -- added by CC on 4/20/2006 for issue#13
                 , ir_interface_mst.pcaf_update_date
                                      -- added by CC on 4/20/2006 for issue#13
                 , ir_interface_mst.salary_update_date
                                      -- added by CC on 4/20/2006 for issue#13
                 , ir_interface_mst.bank_update_date
                                      -- added by CC on 4/20/2006 for issue#13
                 , ir_interface_mst.address_update_date
                                      -- added by CC on 4/20/2006 for issue#13
                 , ir_interface_mst.contract_active_end_date
                                                   -- added by CC on 4/27/2006
                 , ir_interface_mst.costing_pct    -- added by CC on 7/12/2006
                 , ir_interface_mst.disability
                                       -- Added by C. Chan 8/30/2006 WO#217631
                 , ir_interface_mst.assignment_status                 -- V 1.0
                  );
--Fnd_File.put_line(Fnd_File.LOG,'Stage 18');
   EXCEPTION
      WHEN OTHERS
      THEN
         fnd_file.put_line (fnd_file.LOG
                          ,    'insert_interface_mst ERROR on ->'
                            || ir_interface_mst.employee_id
                           );
         fnd_file.put_line (fnd_file.LOG, SUBSTR (SQLERRM, 1, 255));
   END;                                      -- procedure insert_interface_mst

   FUNCTION delimit_text (
      iv_number_of_fields   IN   NUMBER
    , iv_field1             IN   VARCHAR2
    , iv_field2             IN   VARCHAR2 DEFAULT NULL
    , iv_field3             IN   VARCHAR2 DEFAULT NULL
    , iv_field4             IN   VARCHAR2 DEFAULT NULL
    , iv_field5             IN   VARCHAR2 DEFAULT NULL
    , iv_field6             IN   VARCHAR2 DEFAULT NULL
    , iv_field7             IN   VARCHAR2 DEFAULT NULL
    , iv_field8             IN   VARCHAR2 DEFAULT NULL
    , iv_field9             IN   VARCHAR2 DEFAULT NULL
    , iv_field10            IN   VARCHAR2 DEFAULT NULL
    , iv_field11            IN   VARCHAR2 DEFAULT NULL
    , iv_field12            IN   VARCHAR2 DEFAULT NULL
    , iv_field13            IN   VARCHAR2 DEFAULT NULL
    , iv_field14            IN   VARCHAR2 DEFAULT NULL
    , iv_field15            IN   VARCHAR2 DEFAULT NULL
    , iv_field16            IN   VARCHAR2 DEFAULT NULL
    , iv_field17            IN   VARCHAR2 DEFAULT NULL
    , iv_field18            IN   VARCHAR2 DEFAULT NULL
    , iv_field19            IN   VARCHAR2 DEFAULT NULL
    , iv_field20            IN   VARCHAR2 DEFAULT NULL
    , iv_field21            IN   VARCHAR2 DEFAULT NULL
    , iv_field22            IN   VARCHAR2 DEFAULT NULL
    , iv_field23            IN   VARCHAR2 DEFAULT NULL
    , iv_field24            IN   VARCHAR2 DEFAULT NULL
    , iv_field25            IN   VARCHAR2 DEFAULT NULL
    , iv_field26            IN   VARCHAR2 DEFAULT NULL
    , iv_field27            IN   VARCHAR2 DEFAULT NULL
    , iv_field28            IN   VARCHAR2 DEFAULT NULL
    , iv_field29            IN   VARCHAR2 DEFAULT NULL
    , iv_field30            IN   VARCHAR2 DEFAULT NULL
    , iv_field31            IN   VARCHAR2 DEFAULT NULL
    , iv_field32            IN   VARCHAR2 DEFAULT NULL
    , iv_field33            IN   VARCHAR2 DEFAULT NULL
    , iv_field34            IN   VARCHAR2 DEFAULT NULL
    , iv_field35            IN   VARCHAR2 DEFAULT NULL
    , iv_field36            IN   VARCHAR2 DEFAULT NULL
    , iv_field37            IN   VARCHAR2 DEFAULT NULL
    , iv_field38            IN   VARCHAR2 DEFAULT NULL
    , iv_field39            IN   VARCHAR2 DEFAULT NULL
    , iv_field40            IN   VARCHAR2 DEFAULT NULL
    , iv_field41            IN   VARCHAR2 DEFAULT NULL
    , iv_field42            IN   VARCHAR2 DEFAULT NULL
    , iv_field43            IN   VARCHAR2 DEFAULT NULL
    , iv_field44            IN   VARCHAR2 DEFAULT NULL
    , iv_field45            IN   VARCHAR2 DEFAULT NULL
    , iv_field46            IN   VARCHAR2 DEFAULT NULL
    , iv_field47            IN   VARCHAR2 DEFAULT NULL
    , iv_field48            IN   VARCHAR2 DEFAULT NULL
    , iv_field49            IN   VARCHAR2 DEFAULT NULL
    , iv_field50            IN   VARCHAR2 DEFAULT NULL
    , iv_field51            IN   VARCHAR2 DEFAULT NULL
    , iv_field52            IN   VARCHAR2 DEFAULT NULL
    , iv_field53            IN   VARCHAR2 DEFAULT NULL
    , iv_field54            IN   VARCHAR2 DEFAULT NULL
    , iv_field55            IN   VARCHAR2 DEFAULT NULL
    , iv_field56            IN   VARCHAR2 DEFAULT NULL
    , iv_field57            IN   VARCHAR2 DEFAULT NULL
    , iv_field58            IN   VARCHAR2 DEFAULT NULL
    , iv_field59            IN   VARCHAR2 DEFAULT NULL
    , iv_field60            IN   VARCHAR2 DEFAULT NULL
    , iv_field61            IN   VARCHAR2 DEFAULT NULL
    , iv_field62            IN   VARCHAR2 DEFAULT NULL
    , iv_field63            IN   VARCHAR2 DEFAULT NULL
    , iv_field64            IN   VARCHAR2 DEFAULT NULL
    , iv_field65            IN   VARCHAR2 DEFAULT NULL
    , iv_field66            IN   VARCHAR2 DEFAULT NULL
    , iv_field67            IN   VARCHAR2 DEFAULT NULL
    , iv_field68            IN   VARCHAR2 DEFAULT NULL
    , iv_field69            IN   VARCHAR2 DEFAULT NULL
    , iv_field70            IN   VARCHAR2 DEFAULT NULL
    , iv_field71            IN   VARCHAR2 DEFAULT NULL
    , iv_field72            IN   VARCHAR2 DEFAULT NULL
    , iv_field73            IN   VARCHAR2 DEFAULT NULL
    , iv_field74            IN   VARCHAR2 DEFAULT NULL
    , iv_field75            IN   VARCHAR2 DEFAULT NULL
    , iv_field76            IN   VARCHAR2 DEFAULT NULL
    , iv_field77            IN   VARCHAR2 DEFAULT NULL
    , iv_field78            IN   VARCHAR2 DEFAULT NULL
    , iv_field79            IN   VARCHAR2 DEFAULT NULL
    , iv_field80            IN   VARCHAR2 DEFAULT NULL
    , iv_field81            IN   VARCHAR2 DEFAULT NULL
    , iv_field82            IN   VARCHAR2 DEFAULT NULL
    , iv_field83            IN   VARCHAR2 DEFAULT NULL
    , iv_field84            IN   VARCHAR2 DEFAULT NULL
    , iv_field85            IN   VARCHAR2 DEFAULT NULL
    , iv_field86            IN   VARCHAR2 DEFAULT NULL
    , iv_field87            IN   VARCHAR2 DEFAULT NULL
    , iv_field88            IN   VARCHAR2 DEFAULT NULL
    , iv_field89            IN   VARCHAR2 DEFAULT NULL
    , iv_field90            IN   VARCHAR2 DEFAULT NULL
    , iv_field91            IN   VARCHAR2 DEFAULT NULL
    , iv_field92            IN   VARCHAR2 DEFAULT NULL
    , iv_field93            IN   VARCHAR2 DEFAULT NULL
    , iv_field94            IN   VARCHAR2 DEFAULT NULL
    , iv_field95            IN   VARCHAR2 DEFAULT NULL
    , iv_field96            IN   VARCHAR2 DEFAULT NULL
    , iv_field97            IN   VARCHAR2 DEFAULT NULL
    , iv_field98            IN   VARCHAR2 DEFAULT NULL
    , iv_field99            IN   VARCHAR2 DEFAULT NULL
    , iv_field100           IN   VARCHAR2 DEFAULT NULL
   )
      RETURN VARCHAR2
   IS
      v_delimiter          VARCHAR2 (1)     := ';';
      v_replacement_char   VARCHAR2 (1)     := ' ';
      v_delimited_text     VARCHAR2 (20000);
   BEGIN
      -- Removes the Delimiter from the fields and replaces it with
      -- Replacement Char, then concatenates the fields together
      -- separated by the delimiter
      v_delimited_text :=
            REPLACE (iv_field1, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field2, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field3, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field4, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field5, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field6, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field7, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field8, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field9, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field10, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field11, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field12, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field13, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field14, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field15, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field16, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field17, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field18, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field19, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field20, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field21, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field22, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field23, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field24, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field25, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field26, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field27, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field28, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field29, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field30, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field31, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field32, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field33, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field34, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field35, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field36, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field37, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field38, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field39, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field40, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field41, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field42, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field43, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field44, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field45, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field46, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field47, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field48, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field49, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field50, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field51, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field52, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field53, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field54, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field55, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field56, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field57, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field58, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field59, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field60, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field61, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field62, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field63, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field64, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field65, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field66, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field67, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field68, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field69, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field70, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field71, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field72, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field73, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field74, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field75, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field76, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field77, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field78, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field79, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field80, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field81, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field82, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field83, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field84, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field85, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field86, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field87, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field88, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field89, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field90, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field91, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field92, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field93, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field94, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field95, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field96, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field97, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field98, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field99, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field100, v_delimiter, v_replacement_char);
      -- return only the number of fields as requested by
      -- the iv_number_of_fields parameter
      v_delimited_text :=
         SUBSTR (v_delimited_text
               , 1
               ,   INSTR (v_delimited_text
                        , v_delimiter
                        , 1
                        , iv_number_of_fields
                         )
                 - 1
                );
      RETURN v_delimited_text;
   EXCEPTION
      WHEN OTHERS
      THEN
         RETURN NULL;
   END;                                                        -- delimit_text

   PROCEDURE get_employee_information (iv_person_id IN NUMBER)
   IS
      CURSOR c_emp
      IS
         SELECT *
           --FROM cust.ttec_spain_pay_interface_mst tbpim  --code commented by RXNETHI-ARGANO,16/05/23
           FROM apps.ttec_spain_pay_interface_mst tbpim    --code added by RXNETHI-ARGANO,16/05/23
          WHERE tbpim.person_id = iv_person_id
            AND tbpim.creation_date =
                              (SELECT MAX (creation_date)
                                 --FROM cust.ttec_spain_pay_interface_mst tbpim1  --code commented by RXNETHI-ARGANO,16/05/23
                                 FROM apps.ttec_spain_pay_interface_mst tbpim1    --code added by RXNETHI-ARGANO,16/05/23
                                WHERE tbpim.person_id = tbpim1.person_id)
            -- Ken to take care of 2 rec (EMP and EX_EMP) for term and final processed and rehired on or before today.
            AND tbpim.system_person_type = 'EMP';

      v_output   VARCHAR2 (4000);
   BEGIN
      FOR r_emp IN c_emp
      LOOP
         v_output :=
            delimit_text
               (iv_number_of_fields      => 79
              , iv_field1                => pad_data_output ('VARCHAR2'
                                                           , 16
                                                           , 'NAEN'
                                                            )
              , iv_field2                => pad_data_output ('VARCHAR2'
                                                           , 30
                                                           , r_emp.employee_id
                                                            )
              , iv_field3                => pad_data_output ('VARCHAR2'
                                                           , 30
                                                           , r_emp.last_name
                                                            )
              , iv_field4                => pad_data_output
                                                       ('VARCHAR2'
                                                      , 30
                                                      , r_emp.second_last_name
                                                       )
              , iv_field5                => pad_data_output ('VARCHAR2'
                                                           , 30
                                                           , r_emp.first_name
                                                            )
              , iv_field6                => TO_CHAR (r_emp.birth_date
                                                   , 'yyyy-mm-dd'
                                                    )
              , iv_field7                => pad_data_output ('VARCHAR2'
                                                           , 30
                                                           , r_emp.gender
                                                            )
              , iv_field8                => pad_data_output ('VARCHAR2'
                                                           , 30
                                                           , r_emp.treatment
                                                            )
              , iv_field9                => pad_data_output ('VARCHAR2'
                                                           , 30
                                                           , r_emp.nationality
                                                            )
              , iv_field10               => pad_data_output ('VARCHAR2'
                                                           , 30
                                                           , r_emp.nif_value
                                                            )
              , iv_field11               => pad_data_output ('VARCHAR2'
                                                           , 30
                                                           , r_emp.nie
                                                            )
              , iv_field12               => pad_data_output
                                                        ('VARCHAR2'
                                                       , 30
                                                       , r_emp.numero_s_social
                                                        )
              , iv_field13               => pad_data_output ('VARCHAR2'
                                                           , 30
                                                           , r_emp.irpf
                                                            )
              , iv_field14               => pad_data_output
                                                           ('VARCHAR2'
                                                          , 30
                                                          , r_emp.id_direccion
                                                           )
              , iv_field15               => pad_data_output
                                                          ('VARCHAR2'
                                                         , 30
                                                         , r_emp.address_line1
                                                          )
              , iv_field16               => pad_data_output
                                                          ('VARCHAR2'
                                                         , 30
                                                         , r_emp.address_line2
                                                          )
              , iv_field17               => pad_data_output ('VARCHAR2'
                                                           , 30
                                                           , r_emp.country
                                                            )
              , iv_field18               => pad_data_output ('VARCHAR2'
                                                           , 30
                                                           , r_emp.region_1
                                                            )
              , iv_field19               => pad_data_output ('VARCHAR2'
                                                           , 30
                                                           , r_emp.postal_code
                                                            )
              , iv_field20               => pad_data_output
                                                          ('VARCHAR2'
                                                         , 30
                                                         , r_emp.address_line3
                                                          )
              , iv_field21               => pad_data_output
                                                        ('VARCHAR2'
                                                       , 30
                                                       , r_emp.ordinal_periodo
                                                        )
              , iv_field22               => TO_CHAR (r_emp.ass_eff_date
                                                   , 'yyyy-mm-dd'
                                                    )
              , iv_field23               => pad_data_output ('VARCHAR2'
                                                           , 30
                                                           , r_emp.motivo_alta
                                                            )
              , iv_field24               => REPLACE (r_emp.fecha_antiguedad
                                                   , '/'
                                                   , '-'
                                                    )
              , iv_field25               => pad_data_output ('VARCHAR2'
                                                           , 30
                                                           , r_emp.fecha_extra
                                                            )
              , iv_field26               => pad_data_output
                                                          ('VARCHAR2'
                                                         , 30
                                                         , r_emp.tipo_empleado
                                                          )
              , iv_field27               => pad_data_output
                                                     ('VARCHAR2'
                                                    , 30
                                                    , r_emp.pago_gestiontiempo
                                                     )
              , iv_field28               => pad_data_output
                                                   ('VARCHAR2'
                                                  , 30
                                                  , r_emp.modelo_de_referencia
                                                   )
              , iv_field29               => pad_data_output
                                                         ('VARCHAR2'
                                                        , 30
                                                        , r_emp.legal_employer
                                                         )
              , iv_field30               => pad_data_output
                                                    ('VARCHAR2'
                                                   , 30
                                                   , r_emp.id_contrato_interno
                                                    )
              , iv_field31               => pad_data_output
                                               ('VARCHAR2'
                                              , 30
                                              , TO_CHAR
                                                   (TO_DATE
                                                       (r_emp.fecha_fin_prevista
                                                      , 'YYYY/MM/DD hh24::mi:ss'
                                                       )
                                                  , 'yyyy-mm-dd'
                                                   )
                                               )
-- Ken Mod 8/10/05 to pull Fecha_fin_periodo field from ctr_information4.per_contracts_f
-- and show it field #32 in NAEN section and field #14 in MAP section
--       , iv_field32            => pad_data_output('VARCHAR2',30,r_emp.Fecha_fin_periodo)
-- C.Chan Mod 9/23/2005 per Matias Boras The field #32 (fecha_fin_periodo_de_prueba) should be blank (NULL).
-- The field #31 would be OK with Per_contract_f.CTR_Information4.
--         ,iv_field32            => pad_data_output('VARCHAR2',30,TO_CHAR(to_date(r_emp.Fecha_fin_periodo,'YYYY/MM/DD hh24::mi:ss'),'yyyy-mm-dd'))
            ,   iv_field32               => pad_data_output ('VARCHAR2'
                                                           , 30
                                                           , NULL
                                                            )
              , iv_field33               => TO_CHAR (r_emp.fecha_fin_contrato
                                                   , 'yyyy-mm-dd'
                                                    )
              , iv_field34               => pad_data_output
                                                  ('VARCHAR2'
                                                 , 30
                                                 , r_emp.clausulas_adicionales
                                                  )
              , iv_field35               => pad_data_output
                                                  ('VARCHAR2'
                                                 , 30
                                                 , r_emp.condicion_desempleado
                                                  )
              , iv_field36               => pad_data_output
                                               ('VARCHAR2'
                                              , 30
                                              , r_emp.relacion_laboral_especial
                                               )
              , iv_field37               => pad_data_output
                                                      ('VARCHAR2'
                                                     , 30
                                                     , r_emp.causa_sustitucion
                                                      )
              , iv_field38               => pad_data_output
                                                   ('VARCHAR2'
                                                  , 30
                                                  , r_emp.mujer_subrepresentda
                                                   )
              , iv_field39               => pad_data_output
                                                ('VARCHAR2'
                                               , 30
                                               , r_emp.incapacitado_readmitido
                                                )
              , iv_field40               => pad_data_output
                                               ('VARCHAR2'
                                              , 30
                                              , r_emp.primer_trabajador_autonomo
                                               )
              , iv_field41               => pad_data_output
                                                       ('VARCHAR2'
                                                      , 30
                                                      , r_emp.exclusion_social
                                                       )
              , iv_field42               => TO_CHAR
                                               (r_emp.fecha_inicio_cont_específico
                                              , 'yyyy-mm-dd'
                                               )
              , iv_field43               => pad_data_output
                                                         ('VARCHAR2'
                                                        , 30
                                                        , r_emp.fic_especifico
                                                         )
              , iv_field44               => pad_data_output
                                                   ('VARCHAR2'
                                                  , 30
                                                  , r_emp.numero_ss_sustituido
                                                   )
              , iv_field45               => pad_data_output
                                                 ('VARCHAR2'
                                                , 30
                                                , r_emp.renta_active_insercion
                                                 )
              , iv_field46               => pad_data_output
                                                   ('VARCHAR2'
                                                  , 30
                                                  , r_emp.mujer_mater_24_meses
                                                   )
              , iv_field47               => pad_data_output
                                                ('VARCHAR2'
                                               , 30
                                               , r_emp.mantiene_contrato_legal
                                                )
              , iv_field48               => pad_data_output
                                                        ('VARCHAR2'
                                                       , 30
                                                       , r_emp.contrato_relevo
                                                        )
              , iv_field49               => pad_data_output
                                                    ('VARCHAR2'
                                                   , 30
                                                   , r_emp.mujer_reincorporada
                                                    )
              , iv_field50               => pad_data_output
                                                   ('VARCHAR2'
                                                  , 30
                                                  , r_emp.excluido_fichero_afi
                                                   )
              , iv_field51               => pad_data_output
                                                           ('VARCHAR2'
                                                          , 30
                                                          , r_emp.normal_hours
                                                           )
              , iv_field52               => pad_data_output ('VARCHAR2'
                                                           , 30
                                                           , r_emp.work_center
                                                            )
              , iv_field53               => pad_data_output ('VARCHAR2'
                                                           , 30
                                                           , r_emp.convenio
                                                            )
              , iv_field54               => pad_data_output ('VARCHAR2'
                                                           , 30
                                                           , r_emp.epigrafe
                                                            )
              , iv_field55               => pad_data_output
                                                           ('VARCHAR2'
                                                          , 30
                                                          , r_emp.grupo_tarifa
                                                           )
              , iv_field56               => pad_data_output
                                                       ('VARCHAR2'
                                                      , 30
                                                      , r_emp.clave_percepcion
                                                       )
              , iv_field57               => pad_data_output ('VARCHAR2'
                                                           , 30
                                                           , r_emp.tax_id
                                                            )
              , iv_field58               => pad_data_output
                                                           ('VARCHAR2'
                                                          , 30
                                                          , r_emp.tipo_salario
                                                           )
              , iv_field59               => pad_data_output
                                                         ('VARCHAR2'
                                                        , 30
                                                        , r_emp.tipo_de_ajuste
                                                         )
              , iv_field60               => pad_data_output ('VARCHAR2'
                                                           , 30
                                                           , r_emp.job_id
                                                            )
              , iv_field61               => pad_data_output ('VARCHAR2'
                                                           , 30
                                                           , r_emp.departmento
                                                            )
              , iv_field62               => pad_data_output
                                                      ('VARCHAR2'
                                                     , 30
                                                     , r_emp.centro_de_trabajo
                                                      )
              , iv_field63               => pad_data_output
                                                         ('VARCHAR2'
                                                        , 30
                                                        , r_emp.nivel_salarial
                                                         )
              , iv_field64               => pad_data_output
                                                       ('VARCHAR2'
                                                      , 30
                                                      , r_emp.centros_de_coste
                                                       )
              , iv_field65               => pad_data_output ('VARCHAR2'
                                                           , 30
                                                           , r_emp.salary
                                                            )
              , iv_field66               => pad_data_output ('VARCHAR2'
                                                           , 30
                                                           , r_emp.bank_name
                                                            )
              , iv_field67               => pad_data_output ('VARCHAR2'
                                                           , 30
                                                           , r_emp.bank_branch
                                                            )
              , iv_field68               => pad_data_output
                                                         ('VARCHAR2'
                                                        , 30
                                                        , r_emp.account_number
                                                         )
              , iv_field69               => pad_data_output ('VARCHAR2'
                                                           , 30
                                                           , r_emp.control_id
                                                            )
              , iv_field70               => pad_data_output
                                                           ('VARCHAR2'
                                                          , 30
                                                          , r_emp.tipo_de_pago
                                                           )
              , iv_field71               => pad_data_output
                                                           ('VARCHAR2'
                                                          , 30
                                                          , r_emp.banco_emisor
                                                           )
              , iv_field72               => pad_data_output ('VARCHAR2'
                                                           , 30
                                                           , r_emp.new_job_id
                                                            )
              , iv_field73               => pad_data_output
                                               ('VARCHAR2'
                                              , 30
                                              , TO_CHAR
                                                   (TO_DATE
                                                       (r_emp.fecha_inicio_bonificacion
                                                      , 'YYYY/MM/DD hh24::mi:ss'
                                                       )
                                                  , 'yyyy-mm-dd'
                                                   )
                                               )
              , iv_field74               => pad_data_output
                                               ('VARCHAR2'
                                              , 30
                                              , TO_CHAR
                                                   (TO_DATE
                                                       (r_emp.fecha_fin_bonificacion
                                                      , 'YYYY/MM/DD hh24::mi:ss'
                                                       )
                                                  , 'yyyy-mm-dd'
                                                   )
                                               )
              , iv_field75               => pad_data_output
                                               ('VARCHAR2'
                                              , 2
                                              , r_emp.marital_status
                                               )
                                      -- WO#131875  added By C.Chan 09/21/2005
              , iv_field76               => pad_data_output
                                               ('VARCHAR2'
                                              , 30
                                              , r_emp.telephone1
                                               )
                                      -- WO#144030  added By C.Chan 12/21/2005
              , iv_field77               => pad_data_output
                                               ('VARCHAR2'
                                              , 30
                                              , r_emp.telephone2
                                               )
                                      -- WO#144030  added By C.Chan 12/21/2005
              , iv_field78               => TO_CHAR
                                                  (r_emp.contract_update_date
                                                 , 'yyyy-mm-dd'
                                                  )
              , iv_field79               => r_emp.disability
                                       -- Added by C. Chan 8/30/2006 WO#217631
               );
          --DBMS_OUTPUT.PUT_LINE(LENGTH(v_output));
          --DBMS_OUTPUT.PUT_LINE(v_output);
         -- print_line('3');
         print_line (v_output);
      END LOOP;                                                       -- c_emp
   END;                                  -- procedure get_employee_information

-- Ken Mod 8/16/05 to create rehire section NAEA starting...
-- ken_naea
   PROCEDURE get_employee_info_rehire (iv_person_id IN NUMBER)
   IS
      CURSOR c_emp
      IS
         SELECT *
           --FROM cust.ttec_spain_pay_interface_mst tbpim  --code commented by RXNETHI-ARGANO,16/05/23
           FROM apps.ttec_spain_pay_interface_mst tbpim    --code added by RXNETHI-ARGANO,16/05/23
          WHERE tbpim.person_id = iv_person_id
            -- WO#131255 By C.Chan 09/22/2005
            AND cut_off_date = g_cut_off_date
            AND tbpim.system_person_type = 'EMP'
            AND NOT EXISTS (
                   SELECT 1
                     --FROM cust.ttec_spain_pay_interface_mst tbpim2  --code commented by RXNETHI-ARGANO,16/05/23
                     FROM apps.ttec_spain_pay_interface_mst tbpim2    --code added by RXNETHI-ARGANO,16/05/23
                    WHERE tbpim2.person_id = tbpim.person_id
                      AND tbpim2.system_person_type = 'EMP'
                      AND tbpim2.assignment_id = tbpim.assignment_id
                      AND tbpim2.assignment_update_date =
                                                  tbpim.assignment_update_date
                      AND tbpim2.last_extract_date =
                             (SELECT MAX (last_extract_date)
                                --FROM cust.ttec_spain_pay_interface_mst tbpim1  --code commented by RXNETHI-ARGANO,16/05/23
                                FROM apps.ttec_spain_pay_interface_mst tbpim1    --code added by RXNETHI-ARGANO,16/05/23
                               WHERE tbpim1.person_id = tbpim.person_id
                                 AND tbpim.system_person_type = 'EMP'
                                 AND tbpim2.assignment_id =
                                                           tbpim.assignment_id
                                 AND tbpim2.assignment_update_date =
                                                  tbpim.assignment_update_date
                                 AND tbpim1.last_extract_date < g_cut_off_date))
            AND tbpim.actual_termination_date IS NULL
            AND tbpim.fecha_inicio_cont_especÍfico =
                   (SELECT MAX (tbpim3.fecha_inicio_cont_especÍfico)
                      --FROM cust.ttec_spain_pay_interface_mst tbpim3  --code commented by RXNETHI-ARGANO,16/05/23
                      FROM apps.ttec_spain_pay_interface_mst tbpim3    --code added by RXNETHI-ARGANO,16/05/23
                     WHERE tbpim3.person_id = tbpim.person_id
                       AND tbpim3.system_person_type = 'EMP'
                       AND tbpim3.assignment_id = tbpim.assignment_id
                       AND tbpim3.assignment_update_date =
                                                  tbpim.assignment_update_date
                       AND tbpim.actual_termination_date IS NULL);

/* SELECT   *
   FROM   cust.ttec_spain_pay_interface_mst tbpim
   WHERE  tbpim.person_id = iv_person_id
   -- WO#131255 By C.Chan 09/22/2005
   AND    cut_off_date = g_cut_off_date
   AND    tbpim.system_person_type = 'EMP'
   AND    NOT EXISTS (SELECT 1
                       FROM   cust.ttec_spain_pay_interface_mst tbpim2
                      WHERE  tbpim2.PERSON_ID                 =  tbpim.PERSON_ID
                       AND tbpim2.creation_date = (SELECT MAX(creation_date)
                                                 FROM    cust.ttec_spain_pay_interface_mst tbpim1
                                                 WHERE  tbpim1.PERSON_ID                 =  tbpim.PERSON_ID
                                                 AND  tbpim1.creation_date < g_cut_off_date));
*/ -- cc
--    AND    tbpim.creation_date = (SELECT MAX(creation_date)
--                        FROM   cust.ttec_spain_pay_interface_mst tbpim1
--               WHERE  tbpim.person_id = tbpim1.person_id)
--         -- Ken to take care of 2 rec (EMP and EX_EMP) for term and final processed and rehired on or before today.
--         AND tbpim.system_person_type = 'EMP';
      v_output   VARCHAR2 (4000);
   BEGIN
      FOR r_emp IN c_emp
      LOOP
         v_output :=
            delimit_text
               (iv_number_of_fields      => 63
              , iv_field1                => pad_data_output ('VARCHAR2'
                                                           , 16
                                                           , 'NAEA'
                                                            )
              , iv_field2                => pad_data_output ('VARCHAR2'
                                                           , 30
                                                           , r_emp.employee_id
                                                            )
              --, iv_field3            => pad_data_output('VARCHAR2',30,r_emp.last_name )
              --, iv_field4            => pad_data_output('VARCHAR2',30,r_emp.second_last_name)
              --, iv_field5            => pad_data_output('VARCHAR2',30,r_emp.first_name)
              --, iv_field6            => TO_CHAR(r_emp.birth_date,'yyyy-mm-dd')
              --, iv_field7            => pad_data_output('VARCHAR2',30,r_emp.gender)
              --, iv_field8            => pad_data_output('VARCHAR2',30,r_emp.treatment)
              --, iv_field9            => pad_data_output('VARCHAR2',30,r_emp.nationality)
              --, iv_field10            => pad_data_output('VARCHAR2',30,r_emp.nif_value)
              --, iv_field11            => pad_data_output('VARCHAR2',30,r_emp.nie)
              --, iv_field12            => pad_data_output('VARCHAR2',30,r_emp.numero_s_social)
              --, iv_field13            => pad_data_output('VARCHAR2',30,r_emp.irpf)
              --, iv_field14            => pad_data_output('VARCHAR2',30,r_emp.id_direccion)
              --, iv_field15            => pad_data_output('VARCHAR2',30,r_emp.address_line1)
              --, iv_field16            => pad_data_output('VARCHAR2',30,r_emp.address_line2)
              --, iv_field17            => pad_data_output('VARCHAR2',30,r_emp.country)
              --, iv_field18            => pad_data_output('VARCHAR2',30,r_emp.region_1)
              --, iv_field19            => pad_data_output('VARCHAR2',30,r_emp.postal_code)
              --, iv_field20            => pad_data_output('VARCHAR2',30,r_emp.address_line3)
            ,   iv_field3                => pad_data_output
                                                        ('VARCHAR2'
                                                       , 30
                                                       , r_emp.ordinal_periodo
                                                        )
              , iv_field4                => TO_CHAR (r_emp.ass_eff_date
                                                   , 'yyyy-mm-dd'
                                                    )
              , iv_field5                => pad_data_output ('VARCHAR2'
                                                           , 30
                                                           , r_emp.motivo_alta
                                                            )
              , iv_field6                => REPLACE (r_emp.fecha_antiguedad
                                                   , '/'
                                                   , '-'
                                                    )
              , iv_field7                => pad_data_output ('VARCHAR2'
                                                           , 30
                                                           , r_emp.fecha_extra
                                                            )
              , iv_field8                => pad_data_output
                                                          ('VARCHAR2'
                                                         , 30
                                                         , r_emp.tipo_empleado
                                                          )
              , iv_field9                => pad_data_output
                                                     ('VARCHAR2'
                                                    , 30
                                                    , r_emp.pago_gestiontiempo
                                                     )
              , iv_field10               => pad_data_output
                                                   ('VARCHAR2'
                                                  , 30
                                                  , r_emp.modelo_de_referencia
                                                   )
              , iv_field11               => pad_data_output
                                                         ('VARCHAR2'
                                                        , 30
                                                        , r_emp.legal_employer
                                                         )
              , iv_field12               => pad_data_output
                                                    ('VARCHAR2'
                                                   , 30
                                                   , r_emp.id_contrato_interno
                                                    )
--  Per Matias Boras email on October 05, 2005 8:29 AM
--  WO 130327: The layout is correct, but the fields 13 and 14 are being populated with the same value than the field 54, and both should be blank.
--
--  , iv_field13            => pad_data_output('VARCHAR2',30,r_emp.Fecha_fin_prevista)
-- Ken Mod 8/10/05 to pull Fecha_fin_periodo field from ctr_information4.per_contracts_f
-- and show it field #32 in NAEN section and field #14 in MAP section
--       , iv_field14            => pad_data_output('VARCHAR2',30,r_emp.Fecha_fin_periodo)
--  Per Matias Boras email on October 05, 2005 8:29 AM
--  WO 130327: The layout is correct, but the fields 13 and 14 are being populated with the same value than the field 54, and both should be blank.
--
--     , iv_field14            => pad_data_output('VARCHAR2',30,TO_CHAR(to_date(r_emp.Fecha_fin_periodo,'YYYY/MM/DD hh24::mi:ss'),'yyyy-mm-dd'))
            ,   iv_field13               => pad_data_output ('VARCHAR2'
                                                           , 30
                                                           , NULL
                                                            )
              , iv_field14               => pad_data_output ('VARCHAR2'
                                                           , 30
                                                           , NULL
                                                            )
              , iv_field15               => TO_CHAR (r_emp.fecha_fin_contrato
                                                   , 'yyyy-mm-dd'
                                                    )
              , iv_field16               => pad_data_output
                                                  ('VARCHAR2'
                                                 , 30
                                                 , r_emp.clausulas_adicionales
                                                  )
              , iv_field17               => pad_data_output
                                                  ('VARCHAR2'
                                                 , 30
                                                 , r_emp.condicion_desempleado
                                                  )
              , iv_field18               => pad_data_output
                                               ('VARCHAR2'
                                              , 30
                                              , r_emp.relacion_laboral_especial
                                               )
              , iv_field19               => pad_data_output
                                                      ('VARCHAR2'
                                                     , 30
                                                     , r_emp.causa_sustitucion
                                                      )
              , iv_field20               => pad_data_output
                                                   ('VARCHAR2'
                                                  , 30
                                                  , r_emp.mujer_subrepresentda
                                                   )
              , iv_field21               => pad_data_output
                                                ('VARCHAR2'
                                               , 30
                                               , r_emp.incapacitado_readmitido
                                                )
              , iv_field22               => pad_data_output
                                               ('VARCHAR2'
                                              , 30
                                              , r_emp.primer_trabajador_autonomo
                                               )
              , iv_field23               => pad_data_output
                                                       ('VARCHAR2'
                                                      , 30
                                                      , r_emp.exclusion_social
                                                       )
              , iv_field24               => TO_CHAR
                                               (r_emp.fecha_inicio_cont_específico
                                              , 'yyyy-mm-dd'
                                               )
              , iv_field25               => pad_data_output
                                                         ('VARCHAR2'
                                                        , 30
                                                        , r_emp.fic_especifico
                                                         )
              , iv_field26               => pad_data_output
                                                   ('VARCHAR2'
                                                  , 30
                                                  , r_emp.numero_ss_sustituido
                                                   )
              , iv_field27               => pad_data_output
                                                 ('VARCHAR2'
                                                , 30
                                                , r_emp.renta_active_insercion
                                                 )
              , iv_field28               => pad_data_output
                                                   ('VARCHAR2'
                                                  , 30
                                                  , r_emp.mujer_mater_24_meses
                                                   )
              , iv_field29               => pad_data_output
                                                ('VARCHAR2'
                                               , 30
                                               , r_emp.mantiene_contrato_legal
                                                )
              , iv_field30               => pad_data_output
                                                        ('VARCHAR2'
                                                       , 30
                                                       , r_emp.contrato_relevo
                                                        )
              , iv_field31               => pad_data_output
                                                    ('VARCHAR2'
                                                   , 30
                                                   , r_emp.mujer_reincorporada
                                                    )
              , iv_field32               => pad_data_output
                                                   ('VARCHAR2'
                                                  , 30
                                                  , r_emp.excluido_fichero_afi
                                                   )
              , iv_field33               => pad_data_output
                                                           ('VARCHAR2'
                                                          , 30
                                                          , r_emp.normal_hours
                                                           )
              , iv_field34               => pad_data_output ('VARCHAR2'
                                                           , 30
                                                           , r_emp.work_center
                                                            )
              , iv_field35               => pad_data_output ('VARCHAR2'
                                                           , 30
                                                           , r_emp.convenio
                                                            )
              , iv_field36               => pad_data_output ('VARCHAR2'
                                                           , 30
                                                           , r_emp.epigrafe
                                                            )
              , iv_field37               => pad_data_output
                                                           ('VARCHAR2'
                                                          , 30
                                                          , r_emp.grupo_tarifa
                                                           )
              , iv_field38               => pad_data_output
                                                       ('VARCHAR2'
                                                      , 30
                                                      , r_emp.clave_percepcion
                                                       )
              , iv_field39               => pad_data_output ('VARCHAR2'
                                                           , 30
                                                           , r_emp.tax_id
                                                            )
              , iv_field40               => pad_data_output
                                                           ('VARCHAR2'
                                                          , 30
                                                          , r_emp.tipo_salario
                                                           )
              , iv_field41               => pad_data_output
                                                         ('VARCHAR2'
                                                        , 30
                                                        , r_emp.tipo_de_ajuste
                                                         )
              , iv_field42               => pad_data_output ('VARCHAR2'
                                                           , 30
                                                           , r_emp.job_id
                                                            )
              , iv_field43               => pad_data_output ('VARCHAR2'
                                                           , 30
                                                           , r_emp.departmento
                                                            )
              , iv_field44               => pad_data_output
                                                      ('VARCHAR2'
                                                     , 30
                                                     , r_emp.centro_de_trabajo
                                                      )
              , iv_field45               => pad_data_output
                                                         ('VARCHAR2'
                                                        , 30
                                                        , r_emp.nivel_salarial
                                                         )
              , iv_field46               => pad_data_output
                                                       ('VARCHAR2'
                                                      , 30
                                                      , r_emp.centros_de_coste
                                                       )
              , iv_field47               => pad_data_output ('VARCHAR2'
                                                           , 30
                                                           , r_emp.salary
                                                            )
              , iv_field48               => pad_data_output ('VARCHAR2'
                                                           , 30
                                                           , r_emp.bank_name
                                                            )
              , iv_field49               => pad_data_output ('VARCHAR2'
                                                           , 30
                                                           , r_emp.bank_branch
                                                            )
              , iv_field50               => pad_data_output
                                                         ('VARCHAR2'
                                                        , 30
                                                        , r_emp.account_number
                                                         )
              , iv_field51               => pad_data_output ('VARCHAR2'
                                                           , 30
                                                           , r_emp.control_id
                                                            )
              , iv_field52               => pad_data_output
                                                           ('VARCHAR2'
                                                          , 30
                                                          , r_emp.tipo_de_pago
                                                           )
              , iv_field53               => pad_data_output
                                                           ('VARCHAR2'
                                                          , 30
                                                          , r_emp.banco_emisor
                                                           )
-- WO#130327 By C. Chan 9/14/05 Add Fecha de fin de Contrato Prevista have to be populated with proposed End Date, from the contrct form. Also
-- rearrange the sequence of the fields
--      , iv_field54            => pad_data_output('VARCHAR2',30,r_emp.new_job_id)
--      , iv_field55  => pad_data_output('VARCHAR2',30,TO_CHAR(to_date(r_emp.Fecha_Inicio_Bonificacion,'YYYY/MM/DD hh24::mi:ss'),'yyyy-mm-dd'))
--      , iv_field56  => pad_data_output('VARCHAR2',30,TO_CHAR(to_date(r_emp.Fecha_Fin_Bonificacion,'YYYY/MM/DD hh24::mi:ss'),'yyyy-mm-dd'))
            ,   iv_field54               => pad_data_output
                                               ('VARCHAR2'
                                              , 30
                                              , TO_CHAR
                                                   (TO_DATE
                                                       (r_emp.fecha_fin_prevista
                                                      , 'YYYY/MM/DD hh24::mi:ss'
                                                       )
                                                  , 'yyyy-mm-dd'
                                                   )
                                               )
              , iv_field55               => pad_data_output
                                               ('VARCHAR2'
                                              , 30
                                              , TO_CHAR
                                                   (TO_DATE
                                                       (r_emp.fecha_inicio_bonificacion
                                                      , 'YYYY/MM/DD hh24::mi:ss'
                                                       )
                                                  , 'yyyy-mm-dd'
                                                   )
                                               )
              , iv_field56               => pad_data_output
                                               ('VARCHAR2'
                                              , 30
                                              , TO_CHAR
                                                   (TO_DATE
                                                       (r_emp.fecha_fin_bonificacion
                                                      , 'YYYY/MM/DD hh24::mi:ss'
                                                       )
                                                  , 'yyyy-mm-dd'
                                                   )
                                               )
              , iv_field57               => pad_data_output ('VARCHAR2'
                                                           , 30
                                                           , r_emp.new_job_id
                                                            )
              , iv_field58               => pad_data_output
                                               ('VARCHAR2'
                                              , 2
                                              , r_emp.marital_status
                                               )
                                      -- WO#131875  added By C.Chan 09/21/2005
              , iv_field59               => pad_data_output
                                               ('VARCHAR2'
                                              , 30
                                              , r_emp.telephone1
                                               )
                                        -- WO#144030 added By C.Chan 2/21/2005
              , iv_field60               => pad_data_output
                                               ('VARCHAR2'
                                              , 30
                                              , r_emp.telephone2
                                               )
                                        -- WO#144030 added By C.Chan 2/21/2005
              , iv_field61               => pad_data_output
                                               ('VARCHAR2'
                                              , 30
                                              , TO_CHAR
                                                   (TO_DATE
                                                       (r_emp.fecha_de_incorporacion
                                                      , 'YYYY/MM/DD hh24::mi:ss'
                                                       )
                                                  , 'yyyy-mm-dd'
                                                   )
                                               )
                                        -- WO#150091 added By C.Chan 2/22/2005
              , iv_field62               => TO_CHAR
                                                  (r_emp.contract_update_date
                                                 , 'yyyy-mm-dd'
                                                  )
              , iv_field63               => r_emp.disability
                                       -- Added by C. Chan 8/30/2006 WO#217631
               );
          --DBMS_OUTPUT.PUT_LINE(LENGTH(v_output));
          --DBMS_OUTPUT.PUT_LINE(v_output);
         -- print_line('3');
         print_line (v_output);
      END LOOP;                                                       -- c_emp
   END;                                  -- procedure get_employee_info_rehire

-- Ken Mod 8/16/05 to create rehire section NAEA ending...
--==================*****
   PROCEDURE get_term_emp_information (iv_person_id IN NUMBER)
   IS
      CURSOR c_emp
      IS
--WO#130329 Termination/rehing in the same day not pulling NAEA and NBE records
/* SELECT  *
   FROM   cust.ttec_spain_pay_interface_mst tbpim
   WHERE  tbpim.person_id = iv_person_id
   AND    tbpim.creation_date = (SELECT MAX(creation_date)
                             FROM   cust.ttec_spain_pay_interface_mst tbpim1
                     WHERE  tbpim.person_id = tbpim1.person_id)
      -- Ken need it due to term and final processed and rehired(2 recs in mst table EMP and EX_EMP
      -- with the same cut_off_date and creation_date) on or before today(v_extract_date=sysdate).
        AND tbpim.system_person_type = 'EX_EMP';
*/
    -- Mod by C. Chan for WO#130329 Termination/rehing in the same day not pulling NAEA and NBE records
         SELECT *
           --FROM cust.ttec_spain_pay_interface_mst INT  --code commented by RXNETHI-ARGANO,16/05/23
           FROM apps.ttec_spain_pay_interface_mst INT    --code added by RXNETHI-ARGANO,16/05/23
          WHERE INT.person_id = iv_person_id
            AND TRUNC (INT.last_extract_date) =
                   (SELECT TRUNC (int1.last_extract_date)
                      --FROM cust.ttec_spain_pay_interface_mst int1  --code commented by RXNETHI-ARGANO,16/05/23
                      FROM apps.ttec_spain_pay_interface_mst int1    --code added by RXNETHI-ARGANO,16/05/23
                     WHERE int1.person_id = INT.person_id
                       AND int1.cut_off_date = g_cut_off_date
                       AND ROWNUM < 2)
            AND INT.actual_termination_date IS NOT NULL
            AND INT.cut_off_date =
                   (SELECT MAX (int3.cut_off_date)
                      --FROM cust.ttec_spain_pay_interface_mst int3  --code commented by RXNETHI-ARGANO,16/05/23
                      FROM apps.ttec_spain_pay_interface_mst int3    --code added by RXNETHI-ARGANO,16/05/23
                     WHERE int3.actual_termination_date IS NOT NULL
                       AND int3.person_id = INT.person_id
                       AND TRUNC (int3.last_extract_date) =
                                                 TRUNC (INT.last_extract_date)
                       AND int3.cut_off_date <= g_cut_off_date);

      v_output   VARCHAR2 (4000);
   BEGIN
      FOR r_emp IN c_emp
      LOOP
         v_output :=
            delimit_text
               (iv_number_of_fields      => 6
              , iv_field1                => pad_data_output ('VARCHAR2'
                                                           , 16
                                                           , 'NBE'
                                                            )
              , iv_field2                => pad_data_output ('VARCHAR2'
                                                           , 30
                                                           , r_emp.employee_id
                                                            )
              , iv_field3                => r_emp.ordinal_periodo
              , iv_field4                => TO_CHAR
                                               (r_emp.actual_termination_date
                                              , 'yyyy-mm-dd'
                                               )
              , iv_field5                => pad_data_output
                                                         ('VARCHAR2'
                                                        , 30
                                                        , r_emp.leaving_reason
                                                         )
              , iv_field6                => TO_CHAR
                                               (r_emp.notified_termination_date
                                              , 'yyyy-mm-dd'
                                               )
                                        -- WO#150091 added By C.Chan 2/22/2005
               );
         --DBMS_OUTPUT.PUT_LINE(LENGTH(v_output));
         print_line (v_output);
      END LOOP;                                                       -- c_emp
   END;                             -- procedure get_term_employee_information

---==================
   PROCEDURE get_emp_add_change (iv_person_id IN NUMBER)
   IS
      CURSOR c_emp
      IS
         SELECT DISTINCT tbpim.person_id, tbpim.employee_id
                       , tbpim.assignment_id, tbpim.address_line1
                       , tbpim.address_line2, tbpim.address_line3
                       , tbpim.country, tbpim.region_1, tbpim.postal_code
                       , tbpim.address_date_start, tbpim.address_update_date
                    --FROM cust.ttec_spain_pay_interface_mst tbpim  --code commented by RXNETHI-ARGANO,16/05/23
                    FROM apps.ttec_spain_pay_interface_mst tbpim    --code added by RXNETHI-ARGANO,16/05/23
                   WHERE tbpim.person_id = iv_person_id
                     AND tbpim.creation_date =
                              (SELECT MAX (creation_date)
                                 --FROM cust.ttec_spain_pay_interface_mst tbpim1  --code commented by RXNETHI-ARGANO,16/05/23
                                 FROM apps.ttec_spain_pay_interface_mst tbpim1    --code added by RXNETHI-ARGANO,16/05/23
                                WHERE tbpim.person_id = tbpim1.person_id);

      v_output       VARCHAR2 (4000);
      addressline1   VARCHAR2 (1000);
      addressline2   VARCHAR2 (1000);
      countrycode    VARCHAR2 (1000);
      region1        VARCHAR2 (1000);
      postalcode     VARCHAR2 (1000);
      addressline3   VARCHAR2 (1000);
   BEGIN
      FOR r_emp IN c_emp
      LOOP
         IF ttec_spain_pay_interface_pkg.record_changed_v
                                                        ('ADDRESS_LINE1'
                                                       , r_emp.person_id
                                                       , r_emp.assignment_id
                                                       , g_cut_off_date
                                                        ) = 'Y'
         THEN
            addressline1 :=
                        pad_data_output ('VARCHAR2', 30, r_emp.address_line1);
         ELSE
            addressline1 := NULL;
         END IF;

         IF ttec_spain_pay_interface_pkg.record_changed_v
                                                         ('ADDRESS_LINE2'
                                                        , r_emp.person_id
                                                        , r_emp.assignment_id
                                                        , g_cut_off_date
                                                         ) = 'Y'
         THEN
            addressline2 :=
                        pad_data_output ('VARCHAR2', 30, r_emp.address_line2);
         ELSE
            addressline2 := NULL;
         END IF;

/* --Commented out by C. Chan on 7/8/2006 for WO#208732
 IF Ttec_Spain_Pay_Interface_Pkg.Record_Changed_V('COUNTRY', r_emp.person_id, r_emp.assignment_id, g_cut_off_date) = 'Y' THEN
     CountryCode := pad_data_output('VARCHAR2',30,r_emp.country);
ELSE
     CountryCode := NULL;
END IF;
IF Ttec_Spain_Pay_Interface_Pkg.Record_Changed_V('REGION_1', r_emp.person_id, r_emp.assignment_id, g_cut_off_date) = 'Y' THEN
    Region1 := pad_data_output('VARCHAR2',30,r_emp.region_1) ;
ELSE
   Region1 := NULL;
END IF;
IF  Ttec_Spain_Pay_Interface_Pkg.Record_Changed_V('POSTAL_CODE', r_emp.person_id, r_emp.assignment_id, g_cut_off_date) = 'Y'  THEN
     PostalCode := pad_data_output('VARCHAR2',30,r_emp.postal_code);
ELSE
    PostalCode := NULL;
END IF;
*/
         IF ttec_spain_pay_interface_pkg.record_changed_v
                                                         ('ADDRESS_LINE3'
                                                        , r_emp.person_id
                                                        , r_emp.assignment_id
                                                        , g_cut_off_date
                                                         ) = 'Y'
         THEN
            addressline3 :=
                        pad_data_output ('VARCHAR2', 30, r_emp.address_line3);
         ELSE
            addressline3 := '0';
         END IF;

         v_output :=
            delimit_text
               (iv_number_of_fields      => 11
              , iv_field1                => pad_data_output ('VARCHAR2'
                                                           , 16
                                                           , 'MDD'
                                                            )
              , iv_field2                => pad_data_output ('VARCHAR2'
                                                           , 30
                                                           , r_emp.employee_id
                                                            )
              , iv_field3                => TO_CHAR (r_emp.address_date_start
                                                   , 'yyyy-mm-dd'
                                                    )
              , iv_field4                => NULL
                                            -- Ken Mod 8/12/05 new requirement to pass address_line1 info for any address changes
              --      , iv_field5            => AddressLine1
            ,   iv_field5                => pad_data_output
                                                          ('VARCHAR2'
                                                         , 30
                                                         , r_emp.address_line1
                                                          )
              , iv_field6                => addressline2
              , iv_field7                => pad_data_output
                                               ('VARCHAR2', 30, r_emp.country)
               -- CountryCode  --Modified by C. Chan on 7/8/2006 for WO#208732
              , iv_field8                => pad_data_output
                                               ('VARCHAR2', 30
                                              , r_emp.region_1)
               -- Region1      --Modified by C. Chan on 7/8/2006 for WO#208732
              , iv_field9                => pad_data_output
                                               ('VARCHAR2'
                                              , 30
                                              , r_emp.postal_code
                                               )
               -- PostalCode   --Modified by C. Chan on 7/8/2006 for WO#208732
              , iv_field10               => addressline3
              , iv_field11               => TO_CHAR
                                                   (r_emp.address_update_date
                                                  , 'yyyy-mm-dd'
                                                   )
               );
         --DBMS_OUTPUT.PUT_LINE(LENGTH(v_output));
         print_line (v_output);
      END LOOP;                                                       -- c_emp
   END;                                                  -- get_emp_add_change

--===================
---======================
   PROCEDURE get_emp_info_change (iv_person_id IN NUMBER)
   IS
      CURSOR c_emp
      IS
         SELECT DISTINCT tbpim.person_id, tbpim.employee_id
                       , tbpim.assignment_id, tbpim.last_name
                       , tbpim.second_last_name, tbpim.first_name
                       , tbpim.birth_date, tbpim.gender, tbpim.treatment
                       , tbpim.nationality, tbpim.nif_value, tbpim.nie
                       , tbpim.numero_s_social, tbpim.irpf
                       , tbpim.person_update_date
                    --FROM cust.ttec_spain_pay_interface_mst tbpim  --code commented by RXNETHI-ARGANO,16/05/23
                    FROM apps.ttec_spain_pay_interface_mst tbpim    --code added by RXNETHI-ARGANO,16/05/23
                   WHERE tbpim.person_id = iv_person_id
                     -- WO#130330 By C.Chan 09/23/2005
                     AND cut_off_date = g_cut_off_date
                     AND NOT EXISTS (
                            SELECT 1
                              --FROM cust.ttec_spain_pay_interface_mst tbpim2  --code commented by RXNETHI-ARGANO,16/05/23
                              FROM apps.ttec_spain_pay_interface_mst tbpim2    --code added by RXNETHI-ARGANO,16/05/23
                             WHERE tbpim2.person_id = tbpim.person_id
                               AND tbpim2.creation_date =
                                      (SELECT MAX (creation_date)
                                         --FROM cust.ttec_spain_pay_interface_mst tbpim1  --code commented by RXNETHI-ARGANO,16/05/23
                                         FROM apps.ttec_spain_pay_interface_mst tbpim1    --code added by RXNETHI-ARGANO,16/05/23
                                        WHERE tbpim1.person_id =
                                                               tbpim.person_id
                                          AND tbpim1.creation_date <
                                                                g_cut_off_date));

      v_output             VARCHAR2 (4000);
      v_last_name          VARCHAR2 (1000);
      v_second_last_name   VARCHAR2 (1000);
      v_first_name         VARCHAR2 (1000);
      v_birth_date         VARCHAR2 (1000);
      v_gender             VARCHAR2 (1000);
      v_treatment          VARCHAR2 (1000);
      v_nationality        VARCHAR2 (1000);
      v_nif_value          VARCHAR2 (1000);
      v_nie                VARCHAR2 (1000);
      v_numero_s_social    VARCHAR2 (1000);
      v_irpf               VARCHAR2 (1000);
      v_irpf_dt            VARCHAR2 (1000);
   BEGIN
      FOR r_emp IN c_emp
      LOOP
         IF ttec_spain_pay_interface_pkg.record_changed_v
                                                        ('LAST_NAME'
                                                       , r_emp.person_id
                                                       , r_emp.assignment_id
                                                       , g_cut_off_date
                                                        ) = 'Y'
         THEN
            v_last_name := pad_data_output ('VARCHAR2', 30, r_emp.last_name);
         ELSE
            v_last_name := NULL;
         END IF;

         IF ttec_spain_pay_interface_pkg.record_changed_v
                                                         ('SECOND_LAST_NAME'
                                                        , r_emp.person_id
                                                        , r_emp.assignment_id
                                                        , g_cut_off_date
                                                         ) = 'Y'
         THEN
            v_second_last_name :=
                     pad_data_output ('VARCHAR2', 30, r_emp.second_last_name);
         ELSE
            v_second_last_name := NULL;
         END IF;

         IF ttec_spain_pay_interface_pkg.record_changed_v
                                                         ('FIRST_NAME'
                                                        , r_emp.person_id
                                                        , r_emp.assignment_id
                                                        , g_cut_off_date
                                                         ) = 'Y'
         THEN
            v_first_name :=
                           pad_data_output ('VARCHAR2', 30, r_emp.first_name);
         ELSE
            v_first_name := NULL;
         END IF;

         IF ttec_spain_pay_interface_pkg.record_changed_v
                                                         ('BIRTH_DATE'
                                                        , r_emp.person_id
                                                        , r_emp.assignment_id
                                                        , g_cut_off_date
                                                         ) = 'Y'
         THEN
            v_birth_date := TO_CHAR (r_emp.birth_date, 'yyyy-mm-dd');
         ELSE
            v_birth_date := NULL;
         END IF;

         IF ttec_spain_pay_interface_pkg.record_changed_v
                                                         ('GENDER'
                                                        , r_emp.person_id
                                                        , r_emp.assignment_id
                                                        , g_cut_off_date
                                                         ) = 'Y'
         THEN
            v_gender := pad_data_output ('VARCHAR2', 30, r_emp.gender);
         ELSE
            v_gender := NULL;
         END IF;

         IF ttec_spain_pay_interface_pkg.record_changed_v
                                                         ('TREATMENT'
                                                        , r_emp.person_id
                                                        , r_emp.assignment_id
                                                        , g_cut_off_date
                                                         ) = 'Y'
         THEN
            v_treatment := pad_data_output ('VARCHAR2', 30, r_emp.treatment);
         ELSE
            v_treatment := NULL;
         END IF;

         IF ttec_spain_pay_interface_pkg.record_changed_v
                                                         ('NATIONALITY'
                                                        , r_emp.person_id
                                                        , r_emp.assignment_id
                                                        , g_cut_off_date
                                                         ) = 'Y'
         THEN
            v_nationality :=
                          pad_data_output ('VARCHAR2', 30, r_emp.nationality);
         ELSE
            v_nationality := NULL;
         END IF;

         IF ttec_spain_pay_interface_pkg.record_changed_v
                                                         ('NIF_VALUE'
                                                        , r_emp.person_id
                                                        , r_emp.assignment_id
                                                        , g_cut_off_date
                                                         ) = 'Y'
         THEN
            v_nif_value := pad_data_output ('VARCHAR2', 30, r_emp.nif_value);
         ELSE
            v_nif_value := NULL;
         END IF;

         IF ttec_spain_pay_interface_pkg.record_changed_v
                                                         ('NIE'
                                                        , r_emp.person_id
                                                        , r_emp.assignment_id
                                                        , g_cut_off_date
                                                         ) = 'Y'
         THEN
            v_nie := pad_data_output ('VARCHAR2', 30, r_emp.nie);
         ELSE
            v_nie := NULL;
         END IF;

         IF ttec_spain_pay_interface_pkg.record_changed_v
                                                         ('NUMERO_S_SOCIAL'
                                                        , r_emp.person_id
                                                        , r_emp.assignment_id
                                                        , g_cut_off_date
                                                         ) = 'Y'
         THEN
            v_numero_s_social :=
                      pad_data_output ('VARCHAR2', 30, r_emp.numero_s_social);
         ELSE
            v_numero_s_social := NULL;
         END IF;

         IF ttec_spain_pay_interface_pkg.record_changed_v
                                                         ('IRPF'
                                                        , r_emp.person_id
                                                        , r_emp.assignment_id
                                                        , g_cut_off_date
                                                         ) = 'Y'
         THEN
            v_irpf := pad_data_output ('VARCHAR2', 30, r_emp.irpf);
            v_irpf_dt :=
                     TO_CHAR (TRUNC (r_emp.person_update_date), 'yyyy-mm-dd');
         ELSE
            v_irpf := NULL;
            v_irpf_dt := NULL;
         END IF;

         v_output :=
            delimit_text (iv_number_of_fields      => 15
                        , iv_field1                => pad_data_output
                                                                  ('VARCHAR2'
                                                                 , 16
                                                                 , 'MDP'
                                                                  )
                        , iv_field2                => pad_data_output
                                                            ('VARCHAR2'
                                                           , 30
                                                           , r_emp.employee_id
                                                            )
                        , iv_field3                => v_last_name
                        , iv_field4                => v_second_last_name
                        , iv_field5                => v_first_name
                        , iv_field6                => v_birth_date
                        , iv_field7                => v_gender
                        , iv_field8                => v_treatment
                        , iv_field9                => v_nationality
                        , iv_field10               => v_nif_value
                        , iv_field11               => v_nie
                        , iv_field12               => v_numero_s_social
                        , iv_field13               => v_irpf
                        , iv_field14               => v_irpf_dt
                        , iv_field15               => TO_CHAR
                                                         (r_emp.person_update_date
                                                        , 'yyyy-mm-dd'
                                                         )
                         );
         --DBMS_OUTPUT.PUT_LINE(LENGTH(v_output));
         print_line (v_output);
      END LOOP;                                                       -- c_emp
   END;                                                 -- get_emp_info_change

---======================
   PROCEDURE get_emp_assignment1_change (iv_person_id IN NUMBER)
   IS
      CURSOR c_emp
      IS
         SELECT *
           --FROM cust.ttec_spain_pay_interface_mst tbpim  --code commented by RXNETHI-ARGANO,16/05/23
           FROM apps.ttec_spain_pay_interface_mst tbpim    --code added by RXNETHI-ARGANO,16/05/23
          WHERE tbpim.person_id = iv_person_id
            --AND    tbpim.creation_date = (SELECT MAX(creation_date)
            AND tbpim.cut_off_date =
                              (SELECT MAX (cut_off_date)
                                 --FROM cust.ttec_spain_pay_interface_mst tbpim1  --code commented by RXNETHI-ARGANO,16/05/23
                                 FROM apps.ttec_spain_pay_interface_mst tbpim1    --code added by RXNETHI-ARGANO,16/05/23
                                WHERE tbpim.person_id = tbpim1.person_id);

      v_output                      VARCHAR2 (4000);
      v_fecha_antiguedad            VARCHAR2 (1000);
      v_tipo_empleado               VARCHAR2 (1000);
      v_normal_hours                VARCHAR2 (1000);
      v_papf_eff_dt                 VARCHAR2 (1000);
      v_work_center                 VARCHAR2 (1000);
      v_paaf_eff_dt                 VARCHAR2 (1000);
      v_modelo_de_referencia        VARCHAR2 (1000);
      v_modelo_de_ref_dt            VARCHAR2 (1000);
      v_convenio                    VARCHAR2 (1000);
      v_epigrafe                    VARCHAR2 (1000);
      v_epigrafe_dt                 VARCHAR2 (1000);
      v_grupo_tarifa                VARCHAR2 (1000);
      v_grupo_tarifa_dt             VARCHAR2 (1000);
      v_clave_percepcion            VARCHAR2 (1000);
      v_clave_percepcion_dt         VARCHAR2 (1000);
      v_tax_id                      VARCHAR2 (1000);
      v_date_start                  VARCHAR2 (1000);
      v_tipo_salario                VARCHAR2 (1000);
      v_tipo_eff_dt                 VARCHAR2 (1000);
      v_tipo_de_ajuste              VARCHAR2 (1000);
      v_fecha_inicio_cont_esp       VARCHAR2 (1000);
      v_fecha_fin_contrato          VARCHAR2 (1000);
      v_fecha_fin_prevista          VARCHAR2 (1000);
      v_fecha_fin_periodo           VARCHAR2 (1000);
      v_fecha_inicio_bonificacion   VARCHAR2 (1000);
      v_fecha_fin_bonificacion      VARCHAR2 (1000);
      v_tot_info_changed            NUMBER;
   BEGIN
      FOR r_emp IN c_emp
      LOOP
         v_tot_info_changed := 0;

         IF ttec_spain_pay_interface_pkg.record_changed_v
                                                       ('FECHA_FIN_CONTRATO'
                                                      , r_emp.person_id
                                                      , r_emp.assignment_id
                                                      , g_cut_off_date
                                                       ) = 'Y'
         THEN
            v_fecha_fin_contrato :=
                             TO_CHAR (r_emp.fecha_fin_contrato, 'yyyy-mm-dd');
            v_fecha_inicio_cont_esp :=
                   TO_CHAR (r_emp.fecha_inicio_cont_específico, 'yyyy-mm-dd');
            v_tot_info_changed := v_tot_info_changed + 1;
            fnd_file.put_line (fnd_file.LOG, 'FECHA_FIN_CONTRATO');
         ELSE
            v_fecha_fin_contrato := NULL;
            v_fecha_inicio_cont_esp := NULL;
         END IF;

         IF ttec_spain_pay_interface_pkg.record_changed_v
                                                         ('FECHA_ANTIGUEDAD'
                                                        , r_emp.person_id
                                                        , r_emp.assignment_id
                                                        , g_cut_off_date
                                                         ) = 'Y'
         THEN
            v_fecha_antiguedad :=
                     pad_data_output ('VARCHAR2', 30, r_emp.fecha_antiguedad);
            v_tot_info_changed := v_tot_info_changed + 1;
            fnd_file.put_line (fnd_file.LOG, 'FECHA_ANTIGUEDAD');
         ELSE
            v_fecha_antiguedad := NULL;
         END IF;

         IF ttec_spain_pay_interface_pkg.record_changed_v
                                                         ('TIPO_EMPLEADO'
                                                        , r_emp.person_id
                                                        , r_emp.assignment_id
                                                        , g_cut_off_date
                                                         ) = 'Y'
         THEN
            v_tipo_empleado :=
                        pad_data_output ('VARCHAR2', 30, r_emp.tipo_empleado);
            v_tot_info_changed := v_tot_info_changed + 1;
            fnd_file.put_line (fnd_file.LOG, 'TIPO_EMPLEADO');
         ELSE
            v_tipo_empleado := '0';
         END IF;

         IF ttec_spain_pay_interface_pkg.record_changed_v
                                                         ('NORMAL_HOURS'
                                                        , r_emp.person_id
                                                        , r_emp.assignment_id
                                                        , g_cut_off_date
                                                         ) = 'Y'
         THEN
            v_normal_hours :=
                         pad_data_output ('VARCHAR2', 30, r_emp.normal_hours);
            v_tot_info_changed := v_tot_info_changed + 1;
            fnd_file.put_line (fnd_file.LOG, 'NORMAL_HOURS');
         ELSE
            v_normal_hours := NULL;
         END IF;

         IF ttec_spain_pay_interface_pkg.record_changed_v
                                                         ('WORK_CENTER'
                                                        , r_emp.person_id
                                                        , r_emp.assignment_id
                                                        , g_cut_off_date
                                                         ) = 'Y'
         THEN
            v_work_center :=
                          pad_data_output ('VARCHAR2', 30, r_emp.work_center);
            v_papf_eff_dt :=
                     TO_CHAR (TRUNC (r_emp.person_update_date), 'yyyy-mm-dd');
            v_tot_info_changed := v_tot_info_changed + 1;
            fnd_file.put_line (fnd_file.LOG, 'WORK_CENTER');
         ELSE
            v_work_center := NULL;
            v_papf_eff_dt := NULL;
         END IF;

-- Ken Mod 7/18/05 added to recognize change for modelo_de_referencia (paaf.ass_attribute10)
         IF ttec_spain_pay_interface_pkg.record_changed_v
                                                         ('MODELO_DE_REF'
                                                        , r_emp.person_id
                                                        , r_emp.assignment_id
                                                        , g_cut_off_date
                                                         ) = 'Y'
         THEN
            v_modelo_de_referencia :=
                 pad_data_output ('VARCHAR2', 30, r_emp.modelo_de_referencia);
            v_modelo_de_ref_dt :=
                           TO_CHAR (TRUNC (r_emp.ass_eff_date), 'yyyy-mm-dd');
            v_tot_info_changed := v_tot_info_changed + 1;
            fnd_file.put_line (fnd_file.LOG, 'MODELO_DE_REF');
         ELSE
            v_modelo_de_referencia := NULL;
            v_modelo_de_ref_dt := NULL;
         END IF;

-- Ken Mod ending..
         IF ttec_spain_pay_interface_pkg.record_changed_v
                                                         ('CONVENIO'
                                                        , r_emp.person_id
                                                        , r_emp.assignment_id
                                                        , g_cut_off_date
                                                         ) = 'Y'
         THEN
            v_convenio := pad_data_output ('VARCHAR2', 30, r_emp.convenio);
            v_paaf_eff_dt :=
                           TO_CHAR (TRUNC (r_emp.ass_eff_date), 'yyyy-mm-dd');
            v_tot_info_changed := v_tot_info_changed + 1;
            fnd_file.put_line (fnd_file.LOG, 'CONVENIO');
         ELSE
            v_convenio := NULL;
            v_paaf_eff_dt := NULL;
         END IF;

         IF ttec_spain_pay_interface_pkg.record_changed_v
                                                         ('EPIGRAFE'
                                                        , r_emp.person_id
                                                        , r_emp.assignment_id
                                                        , g_cut_off_date
                                                         ) = 'Y'
         THEN
            v_epigrafe := pad_data_output ('VARCHAR2', 30, r_emp.epigrafe);
            v_epigrafe_dt :=
                            TO_CHAR (TRUNC (r_emp.epigrafe_dt), 'yyyy-mm-dd');
            v_tot_info_changed := v_tot_info_changed + 1;
            fnd_file.put_line (fnd_file.LOG, 'EPIGRAFE');
         ELSE
            v_epigrafe := NULL;
            v_epigrafe_dt := NULL;
         END IF;

         IF ttec_spain_pay_interface_pkg.record_changed_v
                                                         ('GRUPO_TARIFA'
                                                        , r_emp.person_id
                                                        , r_emp.assignment_id
                                                        , g_cut_off_date
                                                         ) = 'Y'
         THEN
            v_grupo_tarifa :=
                         pad_data_output ('VARCHAR2', 30, r_emp.grupo_tarifa);
            v_grupo_tarifa_dt :=
                           TO_CHAR (TRUNC (r_emp.ass_eff_date), 'yyyy-mm-dd');
            v_tot_info_changed := v_tot_info_changed + 1;
            fnd_file.put_line (fnd_file.LOG, 'GRUPO_TARIFA');
         ELSE
            v_grupo_tarifa := NULL;
            v_grupo_tarifa_dt := NULL;
         END IF;

         IF ttec_spain_pay_interface_pkg.record_changed_v
                                                         ('CLAVE_PERCEPCION'
                                                        , r_emp.person_id
                                                        , r_emp.assignment_id
                                                        , g_cut_off_date
                                                         ) = 'Y'
         THEN
            v_clave_percepcion :=
                     pad_data_output ('VARCHAR2', 30, r_emp.clave_percepcion);
            v_tot_info_changed := v_tot_info_changed + 1;
            fnd_file.put_line (fnd_file.LOG, 'CLAVE_PERCEPCION');
         ELSE
            v_clave_percepcion := NULL;
         END IF;

         IF ttec_spain_pay_interface_pkg.record_changed_v
                                                         ('TAX_ID'
                                                        , r_emp.person_id
                                                        , r_emp.assignment_id
                                                        , g_cut_off_date
                                                         ) = 'Y'
         THEN
            v_tax_id := pad_data_output ('VARCHAR2', 30, r_emp.tax_id);
            v_clave_percepcion_dt :=
                     TO_CHAR (TRUNC (r_emp.person_update_date), 'yyyy-mm-dd');
            v_tot_info_changed := v_tot_info_changed + 1;
            fnd_file.put_line (fnd_file.LOG, 'TAX_ID');
         ELSE
            v_tax_id := NULL;
            v_clave_percepcion_dt := NULL;
         END IF;

         IF ttec_spain_pay_interface_pkg.record_changed_v
                                                         ('DATE_START'
                                                        , r_emp.person_id
                                                        , r_emp.assignment_id
                                                        , g_cut_off_date
                                                         ) = 'Y'
         THEN
            v_date_start := TO_CHAR (r_emp.date_start, 'dd_mm_yyyy');
            v_tot_info_changed := v_tot_info_changed + 1;
            fnd_file.put_line (fnd_file.LOG, 'DATE_START');
         ELSE
            v_date_start := NULL;
         END IF;

         IF ttec_spain_pay_interface_pkg.record_changed_v
                                                         ('TIPO_SALARIO'
                                                        , r_emp.person_id
                                                        , r_emp.assignment_id
                                                        , g_cut_off_date
                                                         ) = 'Y'
         THEN
            v_tipo_salario :=
                         pad_data_output ('VARCHAR2', 30, r_emp.tipo_salario);
            v_tot_info_changed := v_tot_info_changed + 1;
            fnd_file.put_line (fnd_file.LOG, 'TIPO_SALARIO');
         ELSE
            v_tipo_salario := NULL;
         END IF;

         IF ttec_spain_pay_interface_pkg.record_changed_v
                                                         ('TIPO_DE_AJUSTE'
                                                        , r_emp.person_id
                                                        , r_emp.assignment_id
                                                        , g_cut_off_date
                                                         ) = 'Y'
         THEN
            v_tipo_de_ajuste :=
                       pad_data_output ('VARCHAR2', 30, r_emp.tipo_de_ajuste);
            v_tipo_eff_dt :=
                     TO_CHAR (TRUNC (r_emp.person_update_date), 'yyyy-mm-dd');
            v_tot_info_changed := v_tot_info_changed + 1;
            fnd_file.put_line (fnd_file.LOG, 'TIPO_DE_AJUSTE');
         ELSE
            v_tipo_de_ajuste := NULL;
            v_tipo_eff_dt := NULL;
         END IF;

-- C.Chan Mod 9/23/05 to track changes of Fecha_fin_prevista field
         IF ttec_spain_pay_interface_pkg.record_changed_v
                                                        ('FECHA_FIN_PREVISTA'
                                                       , r_emp.person_id
                                                       , r_emp.assignment_id
                                                       , g_cut_off_date
                                                        ) = 'Y'
         THEN
            v_fecha_fin_prevista :=
               pad_data_output ('VARCHAR2'
                              , 30
                              , TO_CHAR (TO_DATE (r_emp.fecha_fin_prevista
                                                , 'YYYY/MM/DD hh24::mi:ss'
                                                 )
                                       , 'yyyy-mm-dd'
                                        )
                               );
            v_tot_info_changed := v_tot_info_changed + 1;
            fnd_file.put_line (fnd_file.LOG, 'FECHA_FIN_PREVISTA');
         ELSE
            v_fecha_fin_prevista := NULL;
         END IF;

-- Ken Mod 8/12/05 to track changes of Fecha_fin_periodo field
         IF ttec_spain_pay_interface_pkg.record_changed_v
                                                         ('FECHA_FIN_PERIODO'
                                                        , r_emp.person_id
                                                        , r_emp.assignment_id
                                                        , g_cut_off_date
                                                         ) = 'Y'
         THEN
            v_fecha_fin_periodo :=
               pad_data_output ('VARCHAR2'
                              , 30
                              , TO_CHAR (TO_DATE (r_emp.fecha_fin_periodo
                                                , 'YYYY/MM/DD hh24::mi:ss'
                                                 )
                                       , 'yyyy-mm-dd'
                                        )
                               );
            v_tot_info_changed := v_tot_info_changed + 1;
            fnd_file.put_line (fnd_file.LOG, 'FECHA_FIN_PERIODO');
         ELSE
            v_fecha_fin_periodo := NULL;
         END IF;

-- Ken Mod 8/29/05 to track changes of Fecha_Inicio_Bonificacion and Fecha_Fin_Bonificacion fields
         IF ttec_spain_pay_interface_pkg.record_changed_v
                                                 ('FECHA_INICIO_BONIFICACION'
                                                , r_emp.person_id
                                                , r_emp.assignment_id
                                                , g_cut_off_date
                                                 ) = 'Y'
         THEN
            v_fecha_inicio_bonificacion :=
               pad_data_output
                         ('VARCHAR2'
                        , 30
                        , TO_CHAR (TO_DATE (r_emp.fecha_inicio_bonificacion
                                          , 'YYYY/MM/DD hh24::mi:ss'
                                           )
                                 , 'yyyy-mm-dd'
                                  )
                         );
            v_tot_info_changed := v_tot_info_changed + 1;
            fnd_file.put_line (fnd_file.LOG, 'FECHA_INICIO_BONIFICACION');
         ELSE
            v_fecha_inicio_bonificacion := NULL;
         END IF;

         IF ttec_spain_pay_interface_pkg.record_changed_v
                                                    ('FECHA_FIN_BONIFICACION'
                                                   , r_emp.person_id
                                                   , r_emp.assignment_id
                                                   , g_cut_off_date
                                                    ) = 'Y'
         THEN
            v_fecha_fin_bonificacion :=
               pad_data_output
                            ('VARCHAR2'
                           , 30
                           , TO_CHAR (TO_DATE (r_emp.fecha_fin_bonificacion
                                             , 'YYYY/MM/DD hh24::mi:ss'
                                              )
                                    , 'yyyy-mm-dd'
                                     )
                            );
            v_tot_info_changed := v_tot_info_changed + 1;
            fnd_file.put_line (fnd_file.LOG, 'FECHA_FIN_BONIFICACION');
         ELSE
            v_fecha_fin_bonificacion := NULL;
         END IF;

         fnd_file.put_line (fnd_file.LOG
                          ,    'MAP Section Employee ID ->'
                            || r_emp.employee_id
                            || ' tot_info_changed -> '
                            || v_tot_info_changed
                           );
         v_output :=
            delimit_text
               (iv_number_of_fields      => 51
              , iv_field1                => pad_data_output ('VARCHAR2'
                                                           , 16
                                                           , 'MAP'
                                                            )
              , iv_field2                => pad_data_output ('VARCHAR2'
                                                           , 30
                                                           , r_emp.employee_id
                                                            )
              , iv_field3                => r_emp.ordinal_periodo
              , iv_field4                => REPLACE (v_fecha_antiguedad
                                                   , '/'
                                                   , '-'
                                                    )
              , iv_field5                => NULL
              , iv_field6                => v_tipo_empleado
              , iv_field7                => NULL
              , iv_field8                => NULL
              -- Ken Mod 7/18/05  pulled field9 and field10 when field10 is changed
              -- field9=paaf.effective_start_date, field10=paaf.ass_attribute10
            ,   iv_field9                => TO_CHAR
                                               (TRUNC (r_emp.ass_eff_date)
                                              , 'yyyy-mm-dd'
                                               )
-- Modify by C. Chan on 12/22/2005. Matias email requested this to be mandatory
              , iv_field10               => v_modelo_de_referencia
                                                         -- Ken Mod ending..
-- C. Chan Oct 31, 2005, Per Matias Boras, this need to be V_FECHA_FIN_PREVISTA instead of NULL
--                             , iv_field11            =>  NULL
            ,   iv_field11               => v_fecha_fin_prevista
              , iv_field12               => NULL
-- C. Chan Oct 27,WO# 130335 Need to show proposed End of Contract date instead of contract end date
--                             , iv_field13            =>  eff.Dat V_FECHA_FIN_CONTRATO
--                                        Modified by CC on 3/14/2006 Should be referenced from outcome
--                             , iv_field13            =>  pad_data_output('VARCHAR2',30,TO_CHAR(to_date(r_emp.Fecha_fin_prevista,'YYYY/MM/DD hh24::mi:ss'),'yyyy-mm-dd'))
            ,   iv_field13               => v_fecha_fin_prevista
-- Ken Mod 8/10/05 to pull Fecha_fin_periodo field from ctr_information4.per_contracts_f
-- and show it field #32 in NAEN section and field #14 in MAP section
                          --         , iv_field14            =>  NULL
-- C. Chan Oct 31, 2005, Per Matias Boras, Need to set this to NULL
--                                       , iv_field14   => V_FECHA_FIN_PERIODO
            ,   iv_field14               => NULL
              , iv_field15               => NULL
              , iv_field16               => NULL
              , iv_field17               => NULL
              , iv_field18               => NULL
              , iv_field19               => NULL
              , iv_field20               => NULL
              , iv_field21               => NULL
              , iv_field22               => v_fecha_inicio_cont_esp
              , iv_field23               => NULL
              , iv_field24               => NULL
              , iv_field25               => NULL
              , iv_field26               => NULL
              , iv_field27               => NULL
              , iv_field28               => NULL
              , iv_field29               => NULL
              , iv_field30               => NULL
              , iv_field31               => NULL
              , iv_field32               => v_normal_hours
              , iv_field33               => v_papf_eff_dt
              , iv_field34               => v_work_center
              , iv_field35               => v_paaf_eff_dt
              , iv_field36               => v_convenio
              , iv_field37               => v_epigrafe_dt
              , iv_field38               => v_epigrafe
              , iv_field39               => v_grupo_tarifa_dt
              , iv_field40               => v_grupo_tarifa
              , iv_field41               => v_clave_percepcion_dt
              , iv_field42               => v_clave_percepcion
              , iv_field43               => v_tax_id
              , iv_field44               => v_date_start
              , iv_field45               => v_tipo_salario
              , iv_field46               => v_tipo_eff_dt
              , iv_field47               => v_tipo_de_ajuste
              , iv_field48               => v_fecha_inicio_bonificacion
              , iv_field49               => v_fecha_fin_bonificacion
              , iv_field50               => TO_CHAR
                                               (r_emp.fecha_inicio_cont_específico
                                              , 'yyyy-mm-dd'
                                               )
 -- WO#147293 By C. Chan 12/22/05  Matias email requested this to be mandatory
              , iv_field51               => pad_data_output
                                               ('VARCHAR2'
                                              , 30
                                              , TO_CHAR
                                                   (TO_DATE
                                                       (r_emp.fecha_fin_prevista
                                                      , 'YYYY/MM/DD hh24::mi:ss'
                                                       )
                                                  , 'yyyy-mm-dd'
                                                   )
                                               )
  -- WO#147293 By C. Chan 12/22/05 Matias email requested this to be mandatory
               );
         --DBMS_OUTPUT.PUT_LINE(LENGTH(v_output));
         print_line (v_output);
      END LOOP;                                                       -- c_emp
   END;                                          -- get_emp_assignment1_change

--=========================
   PROCEDURE get_emp_assignment2_change (iv_person_id IN NUMBER)
   IS
      CURSOR c_emp
      IS
         SELECT *
           --FROM cust.ttec_spain_pay_interface_mst tbpim  --code commented by RXNETHI-ARGANO,16/05/23
           FROM apps.ttec_spain_pay_interface_mst tbpim    --code added by RXNETHI-ARGANO,16/05/23
          WHERE tbpim.person_id = iv_person_id
            AND tbpim.creation_date =
                              (SELECT MAX (creation_date)
                                 --FROM cust.ttec_spain_pay_interface_mst tbpim1  --code commented by RXNETHI-ARGANO,16/05/23
                                 FROM apps.ttec_spain_pay_interface_mst tbpim1    --code added by RXNETHI-ARGANO,16/05/23
                                WHERE tbpim.person_id = tbpim1.person_id);

      v_output                 VARCHAR2 (4000);
      v_job_id                 VARCHAR2 (1000);
      v_new_job_id             VARCHAR2 (1000);
      v_job_id_dt              VARCHAR2 (1000);
      v_departmento            VARCHAR2 (1000);
      v_departmento_dt         VARCHAR2 (1000);
      v_centro_de_trabajo      VARCHAR2 (1000);
      v_centro_de_trabajo_dt   VARCHAR2 (1000);
      v_salary_change_date     VARCHAR2 (1000);
      v_nivel_salarial         VARCHAR2 (1000);
      v_centros_de_coste       VARCHAR2 (1000);
      v_centros_de_coste_dt    VARCHAR2 (1000);
   BEGIN
      FOR r_emp IN c_emp
      LOOP
         IF ttec_spain_pay_interface_pkg.record_changed_v
                                                        ('NEW_JOB_ID'
                                                       , r_emp.person_id
                                                       , r_emp.assignment_id
                                                       , g_cut_off_date
                                                        ) = 'Y'
         THEN
            v_new_job_id :=
                           pad_data_output ('VARCHAR2', 30, r_emp.new_job_id);
         ELSE
            v_new_job_id := NULL;
         END IF;

         IF ttec_spain_pay_interface_pkg.record_changed_v
                                                         ('DEPARTMENTO'
                                                        , r_emp.person_id
                                                        , r_emp.assignment_id
                                                        , g_cut_off_date
                                                         ) = 'Y'
         THEN
            v_departmento :=
                          pad_data_output ('VARCHAR2', 30, r_emp.departmento);
            v_departmento_dt := TO_CHAR (r_emp.ass_eff_date, 'yyyy-mm-dd');
         ELSE
            v_departmento := '0';
            v_departmento_dt := NULL;
         END IF;

         IF ttec_spain_pay_interface_pkg.record_changed_v
                                                         ('CENTRO_DE_TRABAJO'
                                                        , r_emp.person_id
                                                        , r_emp.assignment_id
                                                        , g_cut_off_date
                                                         ) = 'Y'
         THEN
            v_centro_de_trabajo :=
                    pad_data_output ('VARCHAR2', 30, r_emp.centro_de_trabajo);
            v_centro_de_trabajo_dt :=
                                   TO_CHAR (r_emp.ass_eff_date, 'yyyy-mm-dd');
         ELSE
            v_centro_de_trabajo := NULL;
            v_centro_de_trabajo_dt := NULL;
         END IF;

         IF ttec_spain_pay_interface_pkg.record_changed_v
                                                         ('JOB_ID'
                                                        , r_emp.person_id
                                                        , r_emp.assignment_id
                                                        , g_cut_off_date
                                                         ) = 'Y'
         THEN
            v_job_id := pad_data_output ('VARCHAR2', 30, r_emp.job_id);
            v_job_id_dt := TO_CHAR (r_emp.ass_eff_date, 'yyyy-mm-dd');
            v_new_job_id :=
                           pad_data_output ('VARCHAR2', 30, r_emp.new_job_id);
            v_departmento :=
                          pad_data_output ('VARCHAR2', 30, r_emp.departmento);
            v_departmento_dt := TO_CHAR (r_emp.ass_eff_date, 'yyyy-mm-dd');
         ELSE
            v_job_id := NULL;
            v_job_id_dt := NULL;
         END IF;

         IF ttec_spain_pay_interface_pkg.record_changed_v
                                                         ('NIVEL_SALARIAL'
                                                        , r_emp.person_id
                                                        , r_emp.assignment_id
                                                        , g_cut_off_date
                                                         ) = 'Y'
         THEN
            v_nivel_salarial :=
                       pad_data_output ('VARCHAR2', 30, r_emp.nivel_salarial);
            v_salary_change_date :=
                                   TO_CHAR (r_emp.ass_eff_date, 'yyyy-mm-dd');
            v_new_job_id :=
                           pad_data_output ('VARCHAR2', 30, r_emp.new_job_id);
         ELSE
            v_nivel_salarial := NULL;
            v_salary_change_date := NULL;
         END IF;

         IF ttec_spain_pay_interface_pkg.record_changed_v
                                                         ('CENTROS_DE_COSTE'
                                                        , r_emp.person_id
                                                        , r_emp.assignment_id
                                                        , g_cut_off_date
                                                         ) = 'Y'
         THEN
            v_centros_de_coste :=
                     pad_data_output ('VARCHAR2', 30, r_emp.centros_de_coste);
            v_centros_de_coste_dt :=
                                 TO_CHAR (r_emp.costsegment_dt, 'yyyy-mm-dd');
         ELSE
            v_centros_de_coste := NULL;
            v_centros_de_coste_dt := NULL;
         END IF;

         v_output :=
            delimit_text (iv_number_of_fields      => 14
                        , iv_field1                => pad_data_output
                                                                  ('VARCHAR2'
                                                                 , 16
                                                                 , 'MAR'
                                                                  )
                        , iv_field2                => pad_data_output
                                                            ('VARCHAR2'
                                                           , 30
                                                           , r_emp.employee_id
                                                            )
                        , iv_field3                => r_emp.ordinal_periodo
                        , iv_field4                => v_job_id_dt
                        , iv_field5                => v_job_id
                        , iv_field6                => v_departmento_dt
                        , iv_field7                => v_departmento
                        , iv_field8                => v_centro_de_trabajo_dt
                        , iv_field9                => v_centro_de_trabajo
                        , iv_field10               => v_salary_change_date
                        , iv_field11               => v_nivel_salarial
                        , iv_field12               => v_centros_de_coste_dt
                        , iv_field13               => v_centros_de_coste
                        , iv_field14               => v_new_job_id
                         );
         --DBMS_OUTPUT.PUT_LINE(LENGTH(v_output));
         print_line (v_output);
      END LOOP;                                                       -- c_emp
   END;                                          -- get_emp_assignment2_change

---========================
   PROCEDURE get_emp_salary_change (iv_person_id IN NUMBER)
   IS
      CURSOR c_emp
      IS
         SELECT *
           --FROM cust.ttec_spain_pay_interface_mst tbpim   --code commented by RXNETHI-ARGANO,16/05/23
           FROM apps.ttec_spain_pay_interface_mst tbpim     --code added by RXNETHI-ARGANO,16/05/23
          WHERE tbpim.person_id = iv_person_id
            AND tbpim.creation_date =
                              (SELECT MAX (creation_date)
                                 --FROM cust.ttec_spain_pay_interface_mst tbpim1  --code commented by RXNETHI-ARGANO,16/05/23
                                 FROM apps.ttec_spain_pay_interface_mst tbpim1    --code added by RXNETHI-ARGANO,16/05/23
                                WHERE tbpim.person_id = tbpim1.person_id);

      v_output               VARCHAR2 (4000);
      v_salary_change_date   VARCHAR2 (1000);
      v_nivel_salarial       VARCHAR2 (1000);
      l_mds_update_date      DATE;
   BEGIN
      FOR r_emp IN c_emp
      LOOP
         IF ttec_spain_pay_interface_pkg.record_changed_v
                                                        ('SALARY'
                                                       , r_emp.person_id
                                                       , r_emp.assignment_id
                                                       , g_cut_off_date
                                                        ) = 'Y'
         THEN
            v_nivel_salarial :=
                               pad_data_output ('VARCHAR2', 30, r_emp.salary);
            v_salary_change_date :=
                             TO_CHAR (r_emp.salary_change_date, 'yyyy-mm-dd');
            l_mds_update_date :=
                             TO_CHAR (r_emp.salary_update_date, 'yyyy-mm-dd');
         ELSE
            v_nivel_salarial := NULL;
            v_salary_change_date := NULL;
         END IF;

         v_output :=
            delimit_text (iv_number_of_fields      => 6
                        , iv_field1                => pad_data_output
                                                                  ('VARCHAR2'
                                                                 , 16
                                                                 , 'MDS'
                                                                  )
                        , iv_field2                => pad_data_output
                                                            ('VARCHAR2'
                                                           , 30
                                                           , r_emp.employee_id
                                                            )
                        , iv_field3                => pad_data_output
                                                         ('VARCHAR2'
                                                        , 30
                                                        , r_emp.ordinal_periodo
                                                         )
                        , iv_field4                => v_salary_change_date
                        , iv_field5                => v_nivel_salarial
                        , iv_field6                => l_mds_update_date
                         );
         --DBMS_OUTPUT.PUT_LINE(LENGTH(v_output));
         print_line (v_output);
      END LOOP;                                                       -- c_emp
   END;                                               -- get_emp_SALARY_change

---============================
   PROCEDURE extract_hires
   IS
/* Ken commented starting....
     CURSOR c_hire IS
     SELECT DISTINCT person_id
       FROM   cust.ttec_spain_pay_interface_mst a
      WHERE  TRUNC(a.creation_date) = g_cut_off_date
         AND    system_person_type = 'EMP';
--       AND    NOT EXISTS (SELECT 'x'
--            FROM   cust.ttec_spain_pay_interface_mst s
--            WHERE  s.person_id = a.person_id
--   AND    TRUNC(s.creation_date) != g_cut_off_date);
*/  -- Ken commented ending...
/* commented out by CC on 3/10/2006
-- Ken Mod 7/23/05 starting...
     Cursor c_hire IS    -- for brand new hire
     select DISTINCT a.person_id
     from   cust.ttec_spain_pay_interface_mst a
     where  trunc(a.creation_date) = g_cut_off_date
     and    system_person_type = 'EMP'
     and    not exists (select 'x'
                        from   cust.ttec_spain_pay_interface_mst s
                        where  person_id = a.person_id
-- Ken Mod 8/15/05 bug fix commented original line and add more stuffs to pull brand new hire for rerun of interface.
--                        and    trunc(s.creation_date) != g_cut_off_date)
                          and    trunc(s.creation_date) != (select max(trunc(creation_date))
                                                           from   cust.ttec_spain_pay_interface_mst
                                                                                   where  person_id = s.person_id
                                                                                   and    trunc(creation_date) < g_cut_off_date));
End of comment by CC on 3/10/2006 */
      CURSOR c_hire
      IS                                                -- for brand new hire
         SELECT DISTINCT a.person_id
                    --FROM cust.ttec_spain_pay_interface_mst a  --code commented by RXNETHI-ARGANO,16/05/23
                    FROM apps.ttec_spain_pay_interface_mst a    --code added by RXNETHI-ARGANO,16/05/23
                   WHERE TRUNC (a.cut_off_date) = g_cut_off_date
                     AND system_person_type = 'EMP'
                     AND original_date_of_hire = g_cut_off_date
                     AND fecha_inicio_cont_específico = g_cut_off_date
                     AND TO_NUMBER (ordinal_periodo) = 1;

/* Ken Mod 8/16/05 pulling rehires is moved to procedure extract_rehires -- commented out starting...
     -- for normal rehire
     UNION
     select DISTINCT a.person_id
     from   cust.ttec_spain_pay_interface_mst a
     where  trunc(a.cut_off_date) = g_cut_off_date
     and    a.system_person_type = 'EMP'
     and    exists (select 'x'
                    from   cust.ttec_spain_pay_interface_mst s
                    where  person_id = a.person_id
                    AND    s.system_person_type = 'EX_EMP'
                    and    trunc(s.cut_off_date) < g_cut_off_date);
     -- and Record_Changed_rehire (a.person_id, g_cut_off_date) = 'Y'  -- no need because where clause already take care of it.
     -- for term and final processed and rehird on or befory today (v_extract_date=sysdate)
     Cursor c_hire_extra IS
     select DISTINCT b.person_id
       from
        (select x.person_id, count(*) record_cnt
           from cust.ttec_spain_pay_interface_mst x
          where x.person_id = x.person_id
            and trunc(x.cut_off_date) = g_cut_off_date
          group by x.person_id) b
      where b.record_cnt > 1 ;
--        and Record_Changed_rehire (b.person_id, g_cut_off_date) = 'Y';
--     select DISTINCT a.person_id
--     from   cust.ttec_spain_pay_interface_mst a
--     where  trunc(a.cut_off_date) = g_cut_off_date
--     and Record_Changed_rehire (a.person_id, g_cut_off_date) = 'Y';
-- Ken Mod 7/23/05 ending.....
*/ -- Ken Mod 8/16/05 pulling rehires is moved to procedure extract_rehires -- commented out ending...
      v_output     VARCHAR2 (4000);
      ov_retcode   NUMBER;
      ov_errbuf    VARCHAR2 (1000);
      cnt          NUMBER;
   BEGIN
/* Ken commented starting....
  FOR r_hire IN c_hire LOOP
  Cnt := 0;
  --print_line(r_hire.person_id);
  SELECT COUNT(*)
  INTO        Cnt
  FROM      cust.ttec_spain_pay_interface_mst s
  WHERE  s.person_id = r_hire.person_id
   AND        s.system_person_type = 'EMP'
   AND       TRUNC(s.cut_off_date) = (SELECT MAX(TRUNC(cut_off_date))
                                        FROM   cust.ttec_spain_pay_interface_mst
                   WHERE  person_id = s.person_id
               AND    assignment_id = s.assignment_id
               AND    TRUNC(cut_off_date) < g_cut_off_date );
  IF cnt = 0 THEN
       get_employee_information(r_hire.person_id);
  END IF;
  END LOOP; -- c_hire
*/ -- Ken commented ending....
-- Ken Mod 7/23/05  term and rehired at the same time - will have mst table EX_EMP, EMP person types 2 records with same cut off date
      FOR r_hire IN c_hire
      LOOP
         fnd_file.put_line (fnd_file.LOG
                          , 'person_id=' || r_hire.person_id || 'PPP'
                           );                                  -- delete_later
         fnd_file.put_line (fnd_file.LOG, 'befoer calling get_employee_emp..');
                                                               -- delete_later
         get_employee_information (r_hire.person_id);
         fnd_file.put_line (fnd_file.LOG, 'AFTER  calling get_employee_emp..');
                                                               -- delete_later
      END LOOP;                                                      -- c_hire

      fnd_file.put_line (fnd_file.LOG
                       , 'normal end of 1st loop...............');
                                                               -- delete_later
/* Ken Mod 8/16/05 pulling rehires is moved to procedure extract_rehires -- commented out starting...
  FOR r_hire IN c_hire_extra LOOP
    Fnd_File.put_line(Fnd_File.LOG,'person_id=' || r_hire.person_id || 'QQQ');     -- delete_later
    IF (Record_Changed_rehire (r_hire.person_id, g_cut_off_date) = 'Y') THEN
    Fnd_File.put_line(Fnd_File.LOG,'befoer calling get_employee_emp..');     -- delete_later
    get_employee_information(r_hire.person_id);
    Fnd_File.put_line(Fnd_File.LOG,'AFTER  calling get_employee_emp..');     -- delete_later
    END IF;
    Fnd_File.put_line(Fnd_File.LOG,'NOT calling get_employee_emp..');     -- delete_later
  END LOOP; -- c_hire_extra
  Fnd_File.put_line(Fnd_File.LOG,'normal end of 2nd loop...............');     -- delete_later
*/ -- Ken Mod 8/16/05 pulling rehires is moved to procedure extract_rehires -- commented out ending...
   EXCEPTION
      WHEN OTHERS
      THEN
         fnd_file.put_line (fnd_file.LOG, 'Error from Extract Hire');
         fnd_file.put_line (fnd_file.LOG
                          , SQLCODE || ' XXX ' || SUBSTR (SQLERRM, 1, 255)
                           );
         ov_retcode := SQLCODE;
         ov_errbuf := SUBSTR (SQLERRM, 1, 255);
   END;                                             -- procedure extract_hires

---============================
-- Ken Mod 8/16/05 starting... to handle rehires in separate section NAEA
   PROCEDURE extract_rehires
   IS
/* commented out by CC on 3/10/2006
     -- for normal rehire
     Cursor c_rehire IS
     select DISTINCT a.person_id
     from   cust.ttec_spain_pay_interface_mst a
     where  trunc(a.cut_off_date) = g_cut_off_date
     and    a.system_person_type = 'EMP'
     and    exists (select 'x'
                    from   cust.ttec_spain_pay_interface_mst s
                    where  person_id = a.person_id
                    AND    s.system_person_type = 'EX_EMP'   -- TT#444301 Modifiedd By C.Chan 2/22/2005
                    and    trunc(s.cut_off_date) < g_cut_off_date);
     -- and Record_Changed_rehire (a.person_id, g_cut_off_date) = 'Y'  -- no need because where clause already take care of it.
     -- for term and final processed and rehird on or befory today (v_extract_date=sysdate)
     Cursor c_hire_extra IS
     select DISTINCT b.person_id
       from
        (select x.person_id, count(*) record_cnt
           from cust.ttec_spain_pay_interface_mst x
          where x.person_id = x.person_id
            and trunc(x.cut_off_date) = g_cut_off_date
          group by x.person_id) b
      where b.record_cnt > 1 ;
--        and Record_Changed_rehire (b.person_id, g_cut_off_date) = 'Y';
--     select DISTINCT a.person_id
--     from   cust.ttec_spain_pay_interface_mst a
--     where  trunc(a.cut_off_date) = g_cut_off_date
--     and Record_Changed_rehire (a.person_id, g_cut_off_date) = 'Y';
-- Ken Mod 7/23/05 ending.....
End of comment by CC on 3/10/2006 */
      CURSOR c_rehire
      IS
         SELECT DISTINCT a.person_id
                    --FROM cust.ttec_spain_pay_interface_mst a  --code commented by RXNETHI-ARGANO,16/05/23
                    FROM apps.ttec_spain_pay_interface_mst a    --code added by RXNETHI-ARGANO,16/05/23
                   WHERE TRUNC (a.cut_off_date) = g_cut_off_date
                     AND system_person_type = 'EMP'
                     -- and    original_date_of_hire != g_cut_off_date
                     AND contract_pps_start_date =
                            g_cut_off_date
                             -- added by CC 4/14/2006 to isolate rehire vs MAP
--  and to_date(FECHA_ANTIGUEDAD,'YYYY/MM/DD') = g_cut_off_date
--     and    (   Fecha_inicio_cont_específico = g_cut_off_date
--              AND ass_eff_date = g_cut_off_date )
                     AND TO_NUMBER (ordinal_periodo) > 1
         UNION
/* V1.0 Add query below to pickup Spain employee who are reinstate after Excedencia */
         SELECT DISTINCT mst.person_id
                    --FROM cust.ttec_spain_pay_interface_mst mst  --code commented by RXNETHI-ARGANO,16/05/23
                    FROM apps.ttec_spain_pay_interface_mst mst    --code added by RXNETHI-ARGANO,16/05/23
                       , per_contracts pcf
                   WHERE TRUNC (mst.cut_off_date) = g_cut_off_date
                     AND mst.person_id = pcf.person_id
                     AND mst.system_person_type = 'EMP'
                     AND pcf.active_start_date = g_cut_off_date
                     AND pcf.status != 'T-TERMINATE'
                     AND g_cut_off_date BETWEEN pcf.active_start_date
                                            AND NVL (pcf.active_end_date
                                                   , '31-DEC-4712'
                                                    )
                     AND TO_NUMBER (ordinal_periodo) > 1;               --V1.0

--   Commented out by CC Employee who got terminated and rehire the same date will never have a system_person_type  of 'EX_EMP'
--     and    exists (select  'x'
--                     from hr.per_all_people_f papf,
--                          hr.per_person_types ppt
--                     where  papf.person_id = a.person_id
--                and    papf.PERSON_TYPE_ID = ppt.PERSON_TYPE_ID
--                     AND    ppt.system_person_type = 'EX_EMP'
--                 AND     papf.effective_start_date    = (SELECT    MAX(papf1.effective_start_date)
--                                              FROM     hr.per_all_people_f papf1
--                                            WHERE    papf1.person_id = papf.person_id
--                                             AND      effective_start_date < g_cut_off_date));
/* c.chan commented out on Jan19,2006
     Cursor c_rehire IS
     select DISTINCT a.person_id
     from   cust.ttec_spain_pay_interface_mst a
     where  trunc(a.cut_off_date) = g_cut_off_date
     and    a.system_person_type = 'EMP'
     and    exists (select 'x'
                    from   hr.per_periods_of_service s
                    where  s.person_id = a.person_id
                    and    trunc(s.date_start) < g_cut_off_date)
     and     not exists(select 'x'
                    from   cust.ttec_spain_pay_interface_mst s
                    where  person_id = a.person_id
                    and    trunc(s.cut_off_date) < g_cut_off_date);
*/
      v_output     VARCHAR2 (4000);
      ov_retcode   NUMBER;
      ov_errbuf    VARCHAR2 (1000);
      cnt          NUMBER;
   BEGIN
-- Ken Mod 7/23/05  term and rehired at the same time - will have mst table EX_EMP, EMP person types 2 records with same cut off date
      FOR r_hire IN c_rehire
      LOOP
         -- Fnd_File.put_line(Fnd_File.LOG,'person_id=' || r_hire.person_id || 'PPP_rehire');     -- delete_later
          --Fnd_File.put_line(Fnd_File.LOG,'befoer calling get_employee_emp_rehire..');     -- delete_later
         get_employee_info_rehire (r_hire.person_id);
      --Fnd_File.put_line(Fnd_File.LOG,'AFTER  calling get_employee_emp_rehire..');     -- delete_later
      END LOOP;                                                    -- c_rehire
/* commented out by CC on 3/10/2006
  Fnd_File.put_line(Fnd_File.LOG,'normal end of 1st loop...............');     -- delete_later
  FOR r_hire IN c_hire_extra LOOP
    Fnd_File.put_line(Fnd_File.LOG,'person_id=' || r_hire.person_id || 'QQQ_rehire');     -- delete_later
    IF (Record_Changed_rehire (r_hire.person_id, g_cut_off_date) = 'Y') THEN
    Fnd_File.put_line(Fnd_File.LOG,'befoer calling get_employee_emp_rehire..');     -- delete_later
    get_employee_info_rehire(r_hire.person_id);
    Fnd_File.put_line(Fnd_File.LOG,'AFTER  calling get_employee_emp_rehire..');     -- delete_later
    END IF;
    Fnd_File.put_line(Fnd_File.LOG,'NOT calling get_employee_emp_rehire..');     -- delete_later
  END LOOP; -- c_hire_extra
  Fnd_File.put_line(Fnd_File.LOG,'normal end of 2nd loop...............');     -- delete_later
End of comment by CC on 3/10/2006 */
   EXCEPTION
      WHEN OTHERS
      THEN
         fnd_file.put_line (fnd_file.LOG, 'Error from Extract REHire');
         fnd_file.put_line (fnd_file.LOG
                          , SQLCODE || ' PPP ' || SUBSTR (SQLERRM, 1, 255)
                           );
         ov_retcode := SQLCODE;
         ov_errbuf := SUBSTR (SQLERRM, 1, 255);
   END;                                           -- procedure extract_rehires

-- Ken mod 8/16/05 ending...
-- Ken Mod 7/23/05
   PROCEDURE record_changed_term_his (
      p_person_id                   IN       NUMBER
    , p_g_sysdate                   IN       DATE
    , p_papf_effective_start_date   OUT      DATE
    , p_papf_effective_end_date     OUT      DATE
    , p_paaf_assignment_id          OUT      NUMBER
    , p_paaf_effective_start_date   OUT      DATE
    , p_paaf_effective_end_date     OUT      DATE
    , p_period_of_service_id        OUT      NUMBER
    , p_actual_termination_date     OUT      DATE
    , p_final_process_date          OUT      DATE
    , p_leaving_reason              OUT      VARCHAR2
    , p_date_start                  OUT      DATE
    , p_term_his                    OUT      VARCHAR2
   )
   IS                                                    -- RETURN VARCHAR2 IS
      CURSOR curr_pps (cv_person_id NUMBER, cv_extract_date DATE)
      IS
         SELECT   *
             --FROM cust.ttec_spain_pay_interface_pps  --code commented by RXNETHI-ARGANO,16/05/23
             FROM apps.ttec_spain_pay_interface_pps    --code added by RXNETHI-ARGANO,16/05/23
            WHERE person_id = cv_person_id
-- Ken Mod 8/11/05 changed extract_date to cut_off_date and g_cut_off_date, there will be only set of pps extract for each run with
-- cut_off_date
--   AND trunc(extract_date) = trunc(cv_extract_date)
              AND TRUNC (cut_off_date) = g_cut_off_date
         ORDER BY date_start;

      CURSOR past_pps (cv_person_id NUMBER, cv_extract_date DATE)
      IS
         SELECT   *
             --FROM cust.ttec_spain_pay_interface_pps   --code commented by RXNETHI-ARGANO,16/05/23
             FROM apps.ttec_spain_pay_interface_pps     --code added by RXNETHI-ARGANO,16/05/23
            WHERE person_id = cv_person_id
--   AND trunc(extract_date) = (select max(trunc(extract_date))
--                                from cust.ttec_spain_pay_interface_pps
--                               where person_id = cv_person_id
--                                 and trunc(extract_date) < trunc(cv_extract_date))
              AND TRUNC (cut_off_date) =
                     (SELECT MAX (TRUNC (cut_off_date))
                        --FROM cust.ttec_spain_pay_interface_pps  --code commented by RXNETHI-ARGANO,16/05/23
                        FROM apps.ttec_spain_pay_interface_pps    --code added by RXNETHI-ARGANO,16/05/23
                       WHERE person_id = cv_person_id
                         AND TRUNC (cut_off_date) < g_cut_off_date)
         ORDER BY date_start;

      i                             BINARY_INTEGER := 0;
      l_v_index                     BINARY_INTEGER;
      l_v_value_to_compare          VARCHAR2 (240);
      curr_record_count             NUMBER         := 0;
      past_record_count             NUMBER         := 0;

      --TYPE pps_rectabtype IS TABLE OF cust.ttec_spain_pay_interface_pps%ROWTYPE  --code commented by RXNETHI-ARGANO,16/05/23
      TYPE pps_rectabtype IS TABLE OF apps.ttec_spain_pay_interface_pps%ROWTYPE    --code added by RXNETHI-ARGANO,16/05/23
         INDEX BY BINARY_INTEGER;

      curr_pps_table                pps_rectabtype;
      past_pps_table                pps_rectabtype;
      v_extract_date                DATE           := p_g_sysdate;
      v_person_id                   NUMBER (10)    := p_person_id;
      v_term_his                    VARCHAR2 (1)   := NULL;
      v_papf_effective_start_date   DATE           := NULL;
      v_papf_effective_end_date     DATE           := NULL;
      v_paaf_assignment_id          NUMBER (10)    := NULL;
      v_paaf_effective_start_date   DATE           := NULL;
      v_paaf_effective_end_date     DATE           := NULL;
      v_period_of_service_id        NUMBER (9)     := NULL;
      v_actual_termination_date     DATE           := NULL;
      v_final_process_date          DATE           := NULL;
      v_leaving_reason              VARCHAR2 (30)  := NULL;
      v_date_start                  DATE           := NULL;
   BEGIN
      i := 0;

      FOR curr_pps_rec IN curr_pps (v_person_id, v_extract_date)
      LOOP
         i := i + 1;
         curr_pps_table (i) := curr_pps_rec;
      END LOOP;

      curr_record_count := curr_pps_table.COUNT;
      i := 0;

      FOR past_pps_rec IN past_pps (v_person_id, v_extract_date)
      LOOP
         i := i + 1;
         past_pps_table (i) := past_pps_rec;
      END LOOP;

      past_record_count := past_pps_table.COUNT;

      IF (past_record_count != 0)
      THEN    -- do not find term for baseline audit table establishment time.
         FOR i IN past_pps_table.FIRST .. past_pps_table.LAST
         LOOP
            IF (    TRUNC (past_pps_table (i).date_start) =
                                         TRUNC (curr_pps_table (i).date_start)
                AND past_pps_table (i).period_of_service_id =
                                       curr_pps_table (i).period_of_service_id
                AND past_pps_table (i).actual_termination_date IS NULL
                AND curr_pps_table (i).actual_termination_date IS NOT NULL
                -- and trunc(curr_pps_table(i).FINAL_PROCESS_DATE) <= trunc(p_g_sysdate)
                AND TRUNC (curr_pps_table (i).final_process_date) <=
                                                                g_cut_off_date
                AND TRUNC (curr_pps_table (i).actual_termination_date) =
                                 TRUNC (curr_pps_table (i).final_process_date)
               )
            THEN
               -- find termination and final processed before or on today(sysdate) and actual term date equal to final process date
               v_term_his := 'Y';
               v_papf_effective_start_date :=
                                 curr_pps_table (i).papf_effective_start_date;
               v_papf_effective_end_date :=
                                   curr_pps_table (i).papf_effective_end_date;
               v_paaf_assignment_id := curr_pps_table (i).paaf_assignment_id;
               v_paaf_effective_start_date :=
                                 curr_pps_table (i).paaf_effective_start_date;
               v_paaf_effective_end_date :=
                                   curr_pps_table (i).paaf_effective_end_date;
               v_period_of_service_id :=
                                      curr_pps_table (i).period_of_service_id;
               v_actual_termination_date :=
                                   curr_pps_table (i).actual_termination_date;
               v_final_process_date := curr_pps_table (i).final_process_date;
               v_leaving_reason := curr_pps_table (i).leaving_reason;
               v_date_start := curr_pps_table (i).date_start;
               p_term_his := v_term_his;
               p_papf_effective_start_date := v_papf_effective_start_date;
               p_papf_effective_end_date := v_papf_effective_end_date;
               p_paaf_assignment_id := v_paaf_assignment_id;
               p_paaf_effective_start_date := v_paaf_effective_start_date;
               p_paaf_effective_end_date := v_paaf_effective_end_date;
               p_period_of_service_id := v_period_of_service_id;
               p_actual_termination_date := v_actual_termination_date;
               p_final_process_date := v_final_process_date;
               p_leaving_reason := v_leaving_reason;
               p_date_start := v_date_start;
               EXIT;                                     /* exits the loop */
            END IF;

            IF (    TRUNC (past_pps_table (i).date_start) =
                                         TRUNC (curr_pps_table (i).date_start)
                AND past_pps_table (i).period_of_service_id =
                                       curr_pps_table (i).period_of_service_id
                AND past_pps_table (i).actual_termination_date IS NULL
                AND curr_pps_table (i).actual_termination_date IS NOT NULL
                -- and trunc(curr_pps_table(i).FINAL_PROCESS_DATE) <= trunc(p_g_sysdate)
                AND TRUNC (curr_pps_table (i).final_process_date) <=
                                                                g_cut_off_date
                AND TRUNC (curr_pps_table (i).actual_termination_date) !=
                                 TRUNC (curr_pps_table (i).final_process_date)
               )
            THEN
               -- find termination and final processed before or on today(sysdate) and actual term date NOT equal to final process date
               v_term_his := 'X';
               v_papf_effective_start_date :=
                                 curr_pps_table (i).papf_effective_start_date;
               v_papf_effective_end_date :=
                                   curr_pps_table (i).papf_effective_end_date;
               v_paaf_assignment_id := curr_pps_table (i).paaf_assignment_id;
               v_paaf_effective_start_date :=
                                 curr_pps_table (i).paaf_effective_start_date;
               v_paaf_effective_end_date :=
                                   curr_pps_table (i).paaf_effective_end_date;
               v_period_of_service_id :=
                                      curr_pps_table (i).period_of_service_id;
               v_actual_termination_date :=
                                   curr_pps_table (i).actual_termination_date;
               v_final_process_date := curr_pps_table (i).final_process_date;
               v_leaving_reason := curr_pps_table (i).leaving_reason;
               v_date_start := curr_pps_table (i).date_start;
               p_term_his := v_term_his;
               p_papf_effective_start_date := v_papf_effective_start_date;
               p_papf_effective_end_date := v_papf_effective_end_date;
               p_paaf_assignment_id := v_paaf_assignment_id;
               p_paaf_effective_start_date := v_paaf_effective_start_date;
               p_paaf_effective_end_date := v_paaf_effective_end_date;
               p_period_of_service_id := v_period_of_service_id;
               p_actual_termination_date := v_actual_termination_date;
               p_final_process_date := v_final_process_date;
               p_leaving_reason := v_leaving_reason;
               p_date_start := v_date_start;
               EXIT;                                     /* exits the loop */
            END IF;
         END LOOP;
      END IF;
   EXCEPTION
      WHEN OTHERS
      THEN
         fnd_file.put_line
                     (fnd_file.LOG
                    , 'IN Record_Changed_term_his loc=600 exception error...'
                     );                                        -- delete_later
         fnd_file.put_line (fnd_file.LOG
                          , SQLCODE || ' XXX ' || SUBSTR (SQLERRM, 1, 255)
                           );
         v_term_his := 'N';
         p_term_his := v_term_his;
   END;                                   -- procedure Record_Changed_term_his

-------------------------------------------------------------------------------------------------------------------
--
-- C.Chan   23-SEP-2005  WO#130329 Termination/rehing in the same day not pulling NAEA and NBE records
-- Rewrite the function above.
--
   FUNCTION record_changed_rehire (p_person_id IN NUMBER, p_g_sysdate IN DATE)
      RETURN VARCHAR2
   IS
      CURSOR rehire_cur_special
      IS
         SELECT 'Y' flag
           /*
		   START R12.2 Upgrade Remediation
		   code commented by RXNETHI-ARGANO,16/05/23
		   FROM cust.ttec_spain_pay_interface_mst INT
              , hr.per_periods_of_service pps
		   */
		   --code added by RXNETHI-ARGANO,16/05/23
		   FROM apps.ttec_spain_pay_interface_mst INT
              , apps.per_periods_of_service pps
		   --END R12.2 Upgrade Remediation
          WHERE INT.person_id = p_person_id
            AND (   (    TRUNC (INT.cut_off_date) = TRUNC (p_g_sysdate)
                     AND INT.system_person_type = 'EX_EMP'
                    )               -- TT#444301 Modifiedd By C.Chan 2/22/2005
                 OR (    pps.period_of_service_id = INT.period_of_service_id
                     AND pps.person_id = p_person_id
                     AND 1 =
                            (SELECT 1
                               --FROM cust.ttec_spain_pay_interface_mst int2  --code commented by RXNETHI-ARGANO,16/05/23
                               FROM apps.ttec_spain_pay_interface_mst int2    --code added by RXNETHI-ARGANO,16/05/23
                              WHERE int2.cut_off_date <= TRUNC (p_g_sysdate)
                                AND int2.person_id = p_person_id
                                AND int2.actual_termination_date =
                                                            pps.date_start - 1
                                AND ROWNUM < 2)
                    )
                );

      l_record_changed   VARCHAR2 (1) := 'N';
   BEGIN
      --Fnd_File.put_line(Fnd_File.LOG,'IN Record_Changed_rehire Rewitten Function with PERSON_ID = ' || p_person_id );     -- delete_later
      FOR rehire IN rehire_cur_special
      LOOP
         -- C.Chan   23-SEP-2005  WO#130329 Termination/rehing in the same day not pulling NAEA and NBE records
              --IF (v_records_table(i) = 'EX_EMP') THEN
         IF rehire.flag = 'Y'
         THEN
            l_record_changed := 'Y';
            --Fnd_File.put_line(Fnd_File.LOG,'IN Record_Changed_rehire YES this person is a rehire   ...' );     -- delete_later
            EXIT;                                        /* exits the loop */
         ELSE
            l_record_changed := 'Y';
         --Fnd_File.put_line(Fnd_File.LOG,'IN Record_Changed_rehire NO this person is a not a rehire   ...' );     -- delete_later
         END IF;
      END LOOP;

      RETURN (l_record_changed);
   EXCEPTION
      WHEN OTHERS
      THEN
         fnd_file.put_line (fnd_file.LOG
                          , 'IN Record_Changed_rehire exception ...'
                           );                                  -- delete_later
         fnd_file.put_line (fnd_file.LOG
                          , SQLCODE || ' XXX ' || SUBSTR (SQLERRM, 1, 255)
                           );
         RETURN (l_record_changed);
   END;                                               -- Record_Changed_rehire

-- ken_rec
   FUNCTION record_changed_v (
      p_column_name     IN   VARCHAR2
    , p_person_id       IN   NUMBER
    , p_assignment_id   IN   NUMBER
    , p_g_sysdate       IN   DATE
   )
      RETURN VARCHAR2
   IS
      CURSOR last_name_cur
      IS
         SELECT NVL (a.last_name, 'X')
           FROM (SELECT TRUNC (cut_off_date), curr.last_name
                   --FROM cust.ttec_spain_pay_interface_mst curr  --code commented by RXNETHI-ARGANO,16/05/23
                   FROM apps.ttec_spain_pay_interface_mst curr    --code added by RXNETHI-ARGANO,16/05/23
                  WHERE curr.person_id = p_person_id
                    AND curr.assignment_id = p_assignment_id
                    AND TRUNC (curr.cut_off_date) = p_g_sysdate
                 UNION
                 SELECT TRUNC (cut_off_date), past.last_name
                   --FROM cust.ttec_spain_pay_interface_mst past  --code commented by RXNETHI-ARGANO,16/05/23
                   FROM apps.ttec_spain_pay_interface_mst past    --code added by RXNETHI-ARGANO,16/05/23
                  WHERE past.person_id = p_person_id
                    AND past.assignment_id = p_assignment_id
                    AND TRUNC (past.cut_off_date) =
                           (SELECT MAX (TRUNC (cut_off_date))
                              --FROM cust.ttec_spain_pay_interface_mst  --code commented by RXNETHI-ARGANO,16/05/23
                              FROM apps.ttec_spain_pay_interface_mst    --code added by RXNETHI-ARGANO,16/05/23
                             WHERE person_id = p_person_id
                               AND assignment_id = p_assignment_id
                               AND TRUNC (cut_off_date) < p_g_sysdate)) a;

      CURSOR second_last_name_cur
      IS
         SELECT NVL (a.second_last_name, 'X')
           FROM (SELECT TRUNC (cut_off_date), curr.second_last_name
                   --FROM cust.ttec_spain_pay_interface_mst curr  --code commented by RXNETHI-ARGANO,16/05/23
                   FROM apps.ttec_spain_pay_interface_mst curr    --code added by RXNETHI-ARGANO,16/05/23
                  WHERE curr.person_id = p_person_id
                    AND curr.assignment_id = p_assignment_id
                    AND TRUNC (curr.cut_off_date) = p_g_sysdate
                 UNION
                 SELECT TRUNC (cut_off_date), past.second_last_name
                   --FROM cust.ttec_spain_pay_interface_mst past  --code commented by RXNETHI-ARGANO,16/05/23
                   FROM apps.ttec_spain_pay_interface_mst past    --code added by RXNETHI-ARGANO,16/05/23
                  WHERE past.person_id = p_person_id
                    AND past.assignment_id = p_assignment_id
                    AND TRUNC (past.cut_off_date) =
                           (SELECT MAX (TRUNC (cut_off_date))
                              --FROM cust.ttec_spain_pay_interface_mst  --code commented by RXNETHI-ARGANO,16/05/23
                              FROM apps.ttec_spain_pay_interface_mst    --code added by RXNETHI-ARGANO,16/05/23
                             WHERE person_id = p_person_id
                               AND assignment_id = p_assignment_id
                               AND TRUNC (cut_off_date) < p_g_sysdate)) a;

      CURSOR first_name_cur
      IS
         SELECT NVL (a.first_name, 'X')
           FROM (SELECT TRUNC (cut_off_date), curr.first_name
                   --FROM cust.ttec_spain_pay_interface_mst curr  --code commented by RXNETHI-ARGANO,16/05/23
                   FROM apps.ttec_spain_pay_interface_mst curr    --code added by RXNETHI-ARGANO,16/05/23
                  WHERE curr.person_id = p_person_id
                    AND curr.assignment_id = p_assignment_id
                    AND TRUNC (curr.cut_off_date) = p_g_sysdate
                 UNION
                 SELECT TRUNC (cut_off_date), past.first_name
                   --FROM cust.ttec_spain_pay_interface_mst past  --code commented by RXNETHI-ARGANO,16/05/23
                   FROM apps.ttec_spain_pay_interface_mst past    --code added by RXNETHI-ARGANO,16/05/23
                  WHERE past.person_id = p_person_id
                    AND past.assignment_id = p_assignment_id
                    AND TRUNC (past.cut_off_date) =
                           (SELECT MAX (TRUNC (cut_off_date))
                              --FROM cust.ttec_spain_pay_interface_mst  --code commented by RXNETHI-ARGANO,16/05/23
                              FROM apps.ttec_spain_pay_interface_mst    --code added by RXNETHI-ARGANO,16/05/23
                             WHERE person_id = p_person_id
                               AND assignment_id = p_assignment_id
                               AND TRUNC (cut_off_date) < p_g_sysdate)) a;

      CURSOR birth_date_cur
      IS
         SELECT NVL (a.birth_date, 'X')
           FROM (SELECT TRUNC (cut_off_date), curr.birth_date
                   --FROM cust.ttec_spain_pay_interface_mst curr  --code commented by RXNETHI-ARGANO,16/05/23
                   FROM apps.ttec_spain_pay_interface_mst curr    --code added by RXNETHI-ARGANO,16/05/23
                  WHERE curr.person_id = p_person_id
                    AND curr.assignment_id = p_assignment_id
                    AND TRUNC (curr.cut_off_date) = p_g_sysdate
                 UNION
                 SELECT TRUNC (cut_off_date), past.birth_date
                   --FROM cust.ttec_spain_pay_interface_mst past  --code commented by RXNETHI-ARGANO,16/05/23
                   FROM apps.ttec_spain_pay_interface_mst past    --code added by RXNETHI-ARGANO,16/05/23
                  WHERE past.person_id = p_person_id
                    AND past.assignment_id = p_assignment_id
                    AND TRUNC (past.cut_off_date) =
                           (SELECT MAX (TRUNC (cut_off_date))
                              --FROM cust.ttec_spain_pay_interface_mst  --code commented by RXNETHI-ARGANO,16/05/23
                              FROM apps.ttec_spain_pay_interface_mst    --code added by RXNETHI-ARGANO,16/05/23
                             WHERE person_id = p_person_id
                               AND assignment_id = p_assignment_id
                               AND TRUNC (cut_off_date) < p_g_sysdate)) a;

      CURSOR gender_cur
      IS
         SELECT NVL (a.gender, 'X')
           FROM (SELECT TRUNC (cut_off_date), curr.gender
                   --FROM cust.ttec_spain_pay_interface_mst curr  --code commented by RXNETHI-ARGANO,16/05/23
                   FROM apps.ttec_spain_pay_interface_mst curr    --code added by RXNETHI-ARGANO,16/05/23
                  WHERE curr.person_id = p_person_id
                    AND curr.assignment_id = p_assignment_id
                    AND TRUNC (curr.cut_off_date) = p_g_sysdate
                 UNION
                 SELECT TRUNC (cut_off_date), past.gender
                   --FROM cust.ttec_spain_pay_interface_mst past  --code commented by RXNETHI-ARGANO,16/05/23
                   FROM apps.ttec_spain_pay_interface_mst past    --code added by RXNETHI-ARGANO,16/05/23
                  WHERE past.person_id = p_person_id
                    AND past.assignment_id = p_assignment_id
                    AND TRUNC (past.cut_off_date) =
                           (SELECT MAX (TRUNC (cut_off_date))
                              --FROM cust.ttec_spain_pay_interface_mst  --code commented by RXNETHI-ARGANO,16/05/23
                              FROM apps.ttec_spain_pay_interface_mst    --code added by RXNETHI-ARGANO,16/05/23
                             WHERE person_id = p_person_id
                               AND assignment_id = p_assignment_id
                               AND TRUNC (cut_off_date) < p_g_sysdate)) a;

      CURSOR treatment_cur
      IS
         SELECT NVL (a.treatment, 'X')
           FROM (SELECT TRUNC (cut_off_date), curr.treatment
                   --FROM cust.ttec_spain_pay_interface_mst curr  --code commented by RXNETHI-ARGANO,16/05/23
                   FROM apps.ttec_spain_pay_interface_mst curr    --code added by RXNETHI-ARGANO,16/05/23
                  WHERE curr.person_id = p_person_id
                    AND curr.assignment_id = p_assignment_id
                    AND TRUNC (curr.cut_off_date) = p_g_sysdate
                 UNION
                 SELECT TRUNC (cut_off_date), past.treatment
                   --FROM cust.ttec_spain_pay_interface_mst past  --code commented by RXNETHI-ARGANO,16/05/23
                   FROM apps.ttec_spain_pay_interface_mst past    --code added by RXNETHI-ARGANO,16/05/23
                  WHERE past.person_id = p_person_id
                    AND past.assignment_id = p_assignment_id
                    AND TRUNC (past.cut_off_date) =
                           (SELECT MAX (TRUNC (cut_off_date))
                              --FROM cust.ttec_spain_pay_interface_mst  --code commented by RXNETHI-ARGANO,16/05/23
                              FROM apps.ttec_spain_pay_interface_mst    --code added by RXNETHI-ARGANO,16/05/23
                             WHERE person_id = p_person_id
                               AND assignment_id = p_assignment_id
                               AND TRUNC (cut_off_date) < p_g_sysdate)) a;

      CURSOR nationality_cur
      IS
         SELECT NVL (a.nationality, 'X')
           FROM (SELECT TRUNC (cut_off_date), curr.nationality
                   --FROM cust.ttec_spain_pay_interface_mst curr  --code commented by RXNETHI-ARGANO,16/05/23
                   FROM apps.ttec_spain_pay_interface_mst curr    --code added by RXNETHI-ARGANO,16/05/23
                  WHERE curr.person_id = p_person_id
                    AND curr.assignment_id = p_assignment_id
                    AND TRUNC (curr.cut_off_date) = p_g_sysdate
                 UNION
                 SELECT TRUNC (cut_off_date), past.nationality
                   --FROM cust.ttec_spain_pay_interface_mst past  --code commented by RXNETHI-ARGANO,16/05/23
                   FROM apps.ttec_spain_pay_interface_mst past    --code added by RXNETHI-ARGANO,16/05/23
                  WHERE past.person_id = p_person_id
                    AND past.assignment_id = p_assignment_id
                    AND TRUNC (past.cut_off_date) =
                           (SELECT MAX (TRUNC (cut_off_date))
                              --FROM cust.ttec_spain_pay_interface_mst  --code commented by RXNETHI-ARGANO,16/05/23
                              FROM apps.ttec_spain_pay_interface_mst    --code added by RXNETHI-ARGANO,16/05/23
                             WHERE person_id = p_person_id
                               AND assignment_id = p_assignment_id
                               AND TRUNC (cut_off_date) < p_g_sysdate)) a;

      CURSOR nif_value_cur
      IS
         SELECT NVL (a.nif_value, 'X')
           FROM (SELECT TRUNC (cut_off_date), curr.nif_value
                   --FROM cust.ttec_spain_pay_interface_mst curr  --code commented by RXNETHI-ARGANO,16/05/23
                   FROM apps.ttec_spain_pay_interface_mst curr    --code added by RXNETHI-ARGANO,16/05/23
                  WHERE curr.person_id = p_person_id
                    AND curr.assignment_id = p_assignment_id
                    AND TRUNC (curr.cut_off_date) = p_g_sysdate
                 UNION
                 SELECT TRUNC (cut_off_date), past.nif_value
                   --FROM cust.ttec_spain_pay_interface_mst past  --code commented by RXNETHI-ARGANO,16/05/23
                   FROM apps.ttec_spain_pay_interface_mst past    --code added by RXNETHI-ARGANO,16/05/23
                  WHERE past.person_id = p_person_id
                    AND past.assignment_id = p_assignment_id
                    AND TRUNC (past.cut_off_date) =
                           (SELECT MAX (TRUNC (cut_off_date))
                              --FROM cust.ttec_spain_pay_interface_mst   --code commented by RXNETHI-ARGANO,16/05/23
                              FROM apps.ttec_spain_pay_interface_mst     --code added by RXNETHI-ARGANO,16/05/23
                             WHERE person_id = p_person_id
                               AND assignment_id = p_assignment_id
                               AND TRUNC (cut_off_date) < p_g_sysdate)) a;

      CURSOR nie_cur
      IS
         SELECT NVL (a.nie, 'X')
           FROM (SELECT TRUNC (cut_off_date), curr.nie
                   --FROM cust.ttec_spain_pay_interface_mst curr  --code commented by RXNETHI-ARGANO,16/05/23
                   FROM apps.ttec_spain_pay_interface_mst curr    --code added by RXNETHI-ARGANO,16/05/23
                  WHERE curr.person_id = p_person_id
                    AND curr.assignment_id = p_assignment_id
                    AND TRUNC (curr.cut_off_date) = p_g_sysdate
                 UNION
                 SELECT TRUNC (cut_off_date), past.nie
                   --FROM cust.ttec_spain_pay_interface_mst past  --code commented by RXNETHI-ARGANO,16/05/23
                   FROM apps.ttec_spain_pay_interface_mst past    --code added by RXNETHI-ARGANO,16/05/23
                  WHERE past.person_id = p_person_id
                    AND past.assignment_id = p_assignment_id
                    AND TRUNC (past.cut_off_date) =
                           (SELECT MAX (TRUNC (cut_off_date))
                              --FROM cust.ttec_spain_pay_interface_mst  --code commented by RXNETHI-ARGANO,16/05/23
                              FROM apps.ttec_spain_pay_interface_mst    --code added by RXNETHI-ARGANO,16/05/23
                             WHERE person_id = p_person_id
                               AND assignment_id = p_assignment_id
                               AND TRUNC (cut_off_date) < p_g_sysdate)) a;

      CURSOR numero_s_social_cur
      IS
         SELECT NVL (a.numero_s_social, 'X')
           FROM (SELECT TRUNC (cut_off_date), curr.numero_s_social
                   --FROM cust.ttec_spain_pay_interface_mst curr  --code commented by RXNETHI-ARGANO,16/05/23
                   FROM apps.ttec_spain_pay_interface_mst curr    --code added by RXNETHI-ARGANO,16/05/23
                  WHERE curr.person_id = p_person_id
                    AND curr.assignment_id = p_assignment_id
                    AND TRUNC (curr.cut_off_date) = p_g_sysdate
                 UNION
                 SELECT TRUNC (cut_off_date), past.numero_s_social
                   --FROM cust.ttec_spain_pay_interface_mst past  --code commented by RXNETHI-ARGANO,16/05/23
                   FROM apps.ttec_spain_pay_interface_mst past    --code added by RXNETHI-ARGANO,16/05/23
                  WHERE past.person_id = p_person_id
                    AND past.assignment_id = p_assignment_id
                    AND TRUNC (past.cut_off_date) =
                           (SELECT MAX (TRUNC (cut_off_date))
                              --FROM cust.ttec_spain_pay_interface_mst  --code commented by RXNETHI-ARGANO,16/05/23
                              FROM apps.ttec_spain_pay_interface_mst    --code added by RXNETHI-ARGANO,16/05/23
                             WHERE person_id = p_person_id
                               AND assignment_id = p_assignment_id
                               AND TRUNC (cut_off_date) < p_g_sysdate)) a;

      CURSOR irpf_cur
      IS
         SELECT NVL (a.irpf, 'X')
           FROM (SELECT TRUNC (cut_off_date), curr.irpf
                   --FROM cust.ttec_spain_pay_interface_mst curr  --code commented by RXNETHI-ARGANO,16/05/23
                   FROM apps.ttec_spain_pay_interface_mst curr    --code added by RXNETHI-ARGANO,16/05/23
                  WHERE curr.person_id = p_person_id
                    AND curr.assignment_id = p_assignment_id
                    AND TRUNC (curr.cut_off_date) = p_g_sysdate
                 UNION
                 SELECT TRUNC (cut_off_date), past.irpf
                   --FROM cust.ttec_spain_pay_interface_mst past  --code commented by RXNETHI-ARGANO,16/05/23
                   FROM apps.ttec_spain_pay_interface_mst past    --code added by RXNETHI-ARGANO,16/05/23
                  WHERE past.person_id = p_person_id
                    AND past.assignment_id = p_assignment_id
                    AND TRUNC (past.cut_off_date) =
                           (SELECT MAX (TRUNC (cut_off_date))
                              --FROM cust.ttec_spain_pay_interface_mst  --code commented by RXNETHI-ARGANO,16/05/23
                              FROM apps.ttec_spain_pay_interface_mst    --code added by RXNETHI-ARGANO,16/05/23
                             WHERE person_id = p_person_id
                               AND assignment_id = p_assignment_id
                               AND TRUNC (cut_off_date) < p_g_sysdate)) a;

      CURSOR id_direccion_cur
      IS
         SELECT NVL (a.id_direccion, 'X')
           FROM (SELECT TRUNC (cut_off_date), curr.id_direccion
                   --FROM cust.ttec_spain_pay_interface_mst curr  --code commented by RXNETHI-ARGANO,16/05/23
                   FROM apps.ttec_spain_pay_interface_mst curr    --code added by RXNETHI-ARGANO,16/05/23
                  WHERE curr.person_id = p_person_id
                    AND curr.assignment_id = p_assignment_id
                    AND TRUNC (curr.cut_off_date) = p_g_sysdate
                 UNION
                 SELECT TRUNC (cut_off_date), past.id_direccion
                   --FROM cust.ttec_spain_pay_interface_mst past  --code commented by RXNETHI-ARGANO,16/05/23
                   FROM apps.ttec_spain_pay_interface_mst past    --code added by RXNETHI-ARGANO,16/05/23
                  WHERE past.person_id = p_person_id
                    AND past.assignment_id = p_assignment_id
                    AND TRUNC (past.cut_off_date) =
                           (SELECT MAX (TRUNC (cut_off_date))
                              --FROM cust.ttec_spain_pay_interface_mst   --code commented by RXNETHI-ARGANO,16/05/23
                              FROM apps.ttec_spain_pay_interface_mst     --code added by RXNETHI-ARGANO,16/05/23
                             WHERE person_id = p_person_id
                               AND assignment_id = p_assignment_id
                               AND TRUNC (cut_off_date) < p_g_sysdate)) a;

      CURSOR address_line1_cur
      IS
         SELECT NVL (a.address_line1, 'X')
           FROM (SELECT TRUNC (cut_off_date), curr.address_line1
                   --FROM cust.ttec_spain_pay_interface_mst curr  --code commented by RXNETHI-ARGANO,16/05/23
                   FROM apps.ttec_spain_pay_interface_mst curr    --code added by RXNETHI-ARGANO,16/05/23
                  WHERE curr.person_id = p_person_id
                    AND curr.assignment_id = p_assignment_id
                    AND TRUNC (curr.cut_off_date) = p_g_sysdate
                 UNION
                 SELECT TRUNC (cut_off_date), past.address_line1
                   --FROM cust.ttec_spain_pay_interface_mst past  --code commented by RXNETHI-ARGANO,16/05/23
                   FROM apps.ttec_spain_pay_interface_mst past    --code added by RXNETHI-ARGANO,16/05/23
                  WHERE past.person_id = p_person_id
                    AND past.assignment_id = p_assignment_id
                    AND TRUNC (past.cut_off_date) =
                           (SELECT MAX (TRUNC (cut_off_date))
                              --FROM cust.ttec_spain_pay_interface_mst  --code commented by RXNETHI-ARGANO,16/05/23
                              FROM apps.ttec_spain_pay_interface_mst    --code added by RXNETHI-ARGANO,16/05/23
                             WHERE person_id = p_person_id
                               AND assignment_id = p_assignment_id
                               AND TRUNC (cut_off_date) < p_g_sysdate)) a;

      CURSOR address_line2_cur
      IS
         SELECT NVL (a.address_line2, 'X')
           FROM (SELECT TRUNC (cut_off_date), curr.address_line2
                   --FROM cust.ttec_spain_pay_interface_mst curr  --code commented by RXNETHI-ARGANO,16/05/23
                   FROM apps.ttec_spain_pay_interface_mst curr    --code added by RXNETHI-ARGANO,16/05/23
                  WHERE curr.person_id = p_person_id
                    AND curr.assignment_id = p_assignment_id
                    AND TRUNC (curr.cut_off_date) = p_g_sysdate
                 UNION
                 SELECT TRUNC (cut_off_date), past.address_line2
                   --FROM cust.ttec_spain_pay_interface_mst past  --code commented by RXNETHI-ARGANO,16/05/23
                   FROM apps.ttec_spain_pay_interface_mst past    --code added by RXNETHI-ARGANO,16/05/23
                  WHERE past.person_id = p_person_id
                    AND past.assignment_id = p_assignment_id
                    AND TRUNC (past.cut_off_date) =
                           (SELECT MAX (TRUNC (cut_off_date))
                              --FROM cust.ttec_spain_pay_interface_mst  --code commented by RXNETHI-ARGANO,16/05/23
                              FROM apps.ttec_spain_pay_interface_mst    --code added by RXNETHI-ARGANO,16/05/23
                             WHERE person_id = p_person_id
                               AND assignment_id = p_assignment_id
                               AND TRUNC (cut_off_date) < p_g_sysdate)) a;

      CURSOR country_cur
      IS
         SELECT NVL (a.country, 'X')
           FROM (SELECT TRUNC (cut_off_date), curr.country
                   --FROM cust.ttec_spain_pay_interface_mst curr  --code commented by RXNETHI-ARGANO,16/05/23
                   FROM apps.ttec_spain_pay_interface_mst curr    --code added by RXNETHI-ARGANO,16/05/23
                  WHERE curr.person_id = p_person_id
                    AND curr.assignment_id = p_assignment_id
                    AND TRUNC (curr.cut_off_date) = p_g_sysdate
                 UNION
                 SELECT TRUNC (cut_off_date), past.country
                   --FROM cust.ttec_spain_pay_interface_mst past  --code commented by RXNETHI-ARGANO,16/05/23
                   FROM apps.ttec_spain_pay_interface_mst past    --code added by RXNETHI-ARGANO,16/05/23
                  WHERE past.person_id = p_person_id
                    AND past.assignment_id = p_assignment_id
                    AND TRUNC (past.cut_off_date) =
                           (SELECT MAX (TRUNC (cut_off_date))
                              --FROM cust.ttec_spain_pay_interface_mst  --code commented by RXNETHI-ARGANO,16/05/23
                              FROM apps.ttec_spain_pay_interface_mst    --code added by RXNETHI-ARGANO,16/05/23
                             WHERE person_id = p_person_id
                               AND assignment_id = p_assignment_id
                               AND TRUNC (cut_off_date) < p_g_sysdate)) a;

      CURSOR region_1_cur
      IS
         SELECT NVL (a.region_1, 'X')
           FROM (SELECT TRUNC (cut_off_date), curr.region_1
                   --FROM cust.ttec_spain_pay_interface_mst curr  --code commented by RXNETHI-ARGANO,16/05/23
                   FROM apps.ttec_spain_pay_interface_mst curr    --code added by RXNETHI-ARGANO,16/05/23
                  WHERE curr.person_id = p_person_id
                    AND curr.assignment_id = p_assignment_id
                    AND TRUNC (curr.cut_off_date) = p_g_sysdate
                 UNION
                 SELECT TRUNC (cut_off_date), past.region_1
                   --FROM cust.ttec_spain_pay_interface_mst past  --code commented by RXNETHI-ARGANO,16/05/23
                   FROM apps.ttec_spain_pay_interface_mst past    --code added by RXNETHI-ARGANO,16/05/23
                  WHERE past.person_id = p_person_id
                    AND past.assignment_id = p_assignment_id
                    AND TRUNC (past.cut_off_date) =
                           (SELECT MAX (TRUNC (cut_off_date))
                              --FROM cust.ttec_spain_pay_interface_mst   --code commented by RXNETHI-ARGANO,16/05/23
                              FROM apps.ttec_spain_pay_interface_mst     --code added by RXNETHI-ARGANO,16/05/23
                             WHERE person_id = p_person_id
                               AND assignment_id = p_assignment_id
                               AND TRUNC (cut_off_date) < p_g_sysdate)) a;

      CURSOR postal_code_cur
      IS
         SELECT NVL (a.postal_code, 'X')
           FROM (SELECT TRUNC (cut_off_date), curr.postal_code
                   --FROM cust.ttec_spain_pay_interface_mst curr  --code commented by RXNETHI-ARGANO,16/05/23
                   FROM apps.ttec_spain_pay_interface_mst curr    --code added by RXNETHI-ARGANO,16/05/23
                  WHERE curr.person_id = p_person_id
                    AND curr.assignment_id = p_assignment_id
                    AND TRUNC (curr.cut_off_date) = p_g_sysdate
                 UNION
                 SELECT TRUNC (cut_off_date), past.postal_code
                   --FROM cust.ttec_spain_pay_interface_mst past  --code commented by RXNETHI-ARGANO,16/05/23
                   FROM apps.ttec_spain_pay_interface_mst past    --code added by RXNETHI-ARGANO,16/05/23
                  WHERE past.person_id = p_person_id
                    AND past.assignment_id = p_assignment_id
                    AND TRUNC (past.cut_off_date) =
                           (SELECT MAX (TRUNC (cut_off_date))
                              --FROM cust.ttec_spain_pay_interface_mst  --code commented by RXNETHI-ARGANO,16/05/23
                              FROM apps.ttec_spain_pay_interface_mst    --code added by RXNETHI-ARGANO,16/05/23
                             WHERE person_id = p_person_id
                               AND assignment_id = p_assignment_id
                               AND TRUNC (cut_off_date) < p_g_sysdate)) a;

      CURSOR address_line3_cur
      IS
         SELECT NVL (a.address_line3, 'X')
           FROM (SELECT TRUNC (cut_off_date), curr.address_line3
                   --FROM cust.ttec_spain_pay_interface_mst curr  --code commented by RXNETHI-ARGANO,16/05/23
                   FROM apps.ttec_spain_pay_interface_mst curr    --code added by RXNETHI-ARGANO,16/05/23
                  WHERE curr.person_id = p_person_id
                    AND curr.assignment_id = p_assignment_id
                    AND TRUNC (curr.cut_off_date) = p_g_sysdate
                 UNION
                 SELECT TRUNC (cut_off_date), past.address_line3
                   --FROM cust.ttec_spain_pay_interface_mst past  --code commented by RXNETHI-ARGANO,16/05/23
                   FROM apps.ttec_spain_pay_interface_mst past    --code added by RXNETHI-ARGANO,16/05/23
                  WHERE past.person_id = p_person_id
                    AND past.assignment_id = p_assignment_id
                    AND TRUNC (past.cut_off_date) =
                           (SELECT MAX (TRUNC (cut_off_date))
                              --FROM cust.ttec_spain_pay_interface_mst  --code commented by RXNETHI-ARGANO,16/05/23
                              FROM apps.ttec_spain_pay_interface_mst    --code added by RXNETHI-ARGANO,16/05/23
                             WHERE person_id = p_person_id
                               AND assignment_id = p_assignment_id
                               AND TRUNC (cut_off_date) < p_g_sysdate)) a;

--==============
--==============
      CURSOR fecha_antiguedad_cur
      IS
         SELECT NVL (a.fecha_antiguedad, 'X')
           FROM (SELECT TRUNC (cut_off_date), curr.fecha_antiguedad
                   --FROM cust.ttec_spain_pay_interface_mst curr  --code commented by RXNETHI-ARGANO,16/05/23
                   FROM apps.ttec_spain_pay_interface_mst curr    --code added by RXNETHI-ARGANO,16/05/23
                  WHERE curr.person_id = p_person_id
                    AND curr.assignment_id = p_assignment_id
                    AND TRUNC (curr.cut_off_date) = p_g_sysdate
                 UNION
                 SELECT TRUNC (cut_off_date), past.fecha_antiguedad
                   --FROM cust.ttec_spain_pay_interface_mst past  --code commented by RXNETHI-ARGANO,16/05/23
                   FROM apps.ttec_spain_pay_interface_mst past    --code added by RXNETHI-ARGANO,16/05/23
                  WHERE past.person_id = p_person_id
                    AND past.assignment_id = p_assignment_id
                    AND TRUNC (past.cut_off_date) =
                           (SELECT MAX (TRUNC (cut_off_date))
                              --FROM cust.ttec_spain_pay_interface_mst  --code commented by RXNETHI-ARGANO,16/05/23
                              FROM apps.ttec_spain_pay_interface_mst    --code added by RXNETHI-ARGANO,16/05/23
                             WHERE person_id = p_person_id
                               AND assignment_id = p_assignment_id
                               AND TRUNC (cut_off_date) < p_g_sysdate)) a;

      CURSOR tipo_empleado_cur
      IS
         SELECT NVL (a.tipo_empleado, 'X')
           FROM (SELECT TRUNC (cut_off_date), curr.tipo_empleado
                   --FROM cust.ttec_spain_pay_interface_mst curr  --code commented by RXNETHI-ARGANO,16/05/23
                   FROM apps.ttec_spain_pay_interface_mst curr    --code added by RXNETHI-ARGANO,16/05/23
                  WHERE curr.person_id = p_person_id
                    AND curr.assignment_id = p_assignment_id
                    AND TRUNC (curr.cut_off_date) = p_g_sysdate
                 UNION
                 SELECT TRUNC (cut_off_date), past.tipo_empleado
                   --FROM cust.ttec_spain_pay_interface_mst past  --code commented by RXNETHI-ARGANO,16/05/23
                   FROM apps.ttec_spain_pay_interface_mst past    --code added by RXNETHI-ARGANO,16/05/23
                  WHERE past.person_id = p_person_id
                    AND past.assignment_id = p_assignment_id
                    AND TRUNC (past.cut_off_date) =
                           (SELECT MAX (TRUNC (cut_off_date))
                              --FROM cust.ttec_spain_pay_interface_mst  --code commented by RXNETHI-ARGANO,16/05/23
                              FROM apps.ttec_spain_pay_interface_mst    --code added by RXNETHI-ARGANO,16/05/23
                             WHERE person_id = p_person_id
                               AND assignment_id = p_assignment_id
                               AND TRUNC (cut_off_date) < p_g_sysdate)) a;

      CURSOR normal_hours_cur
      IS
         SELECT NVL (a.normal_hours, 99999)
           FROM (SELECT TRUNC (cut_off_date), curr.normal_hours
                   --FROM cust.ttec_spain_pay_interface_mst curr  --code commented by RXNETHI-ARGANO,16/05/23
                   FROM apps.ttec_spain_pay_interface_mst curr    --code added by RXNETHI-ARGANO,16/05/23
                  WHERE curr.person_id = p_person_id
                    AND curr.assignment_id = p_assignment_id
                    AND TRUNC (curr.cut_off_date) = p_g_sysdate
                 UNION
                 SELECT TRUNC (cut_off_date), past.normal_hours
                   --FROM cust.ttec_spain_pay_interface_mst past  --code commented by RXNETHI-ARGANO,16/05/23
                   FROM apps.ttec_spain_pay_interface_mst past    --code added by RXNETHI-ARGANO,16/05/23
                  WHERE past.person_id = p_person_id
                    AND past.assignment_id = p_assignment_id
                    AND TRUNC (past.cut_off_date) =
                           (SELECT MAX (TRUNC (cut_off_date))
                              --FROM cust.ttec_spain_pay_interface_mst  --code commented by RXNETHI-ARGANO,16/05/23
                              FROM apps.ttec_spain_pay_interface_mst    --code added by RXNETHI-ARGANO,16/05/23
                             WHERE person_id = p_person_id
                               AND assignment_id = p_assignment_id
                               AND TRUNC (cut_off_date) < p_g_sysdate)) a;

      CURSOR work_center_cur
      IS
         SELECT NVL (a.work_center, 'X')
           FROM (SELECT TRUNC (cut_off_date), curr.work_center
                   --FROM cust.ttec_spain_pay_interface_mst curr  --code commented by RXNETHI-ARGANO,16/05/23
                   FROM apps.ttec_spain_pay_interface_mst curr    --code added by RXNETHI-ARGANO,16/05/23
                  WHERE curr.person_id = p_person_id
                    AND curr.assignment_id = p_assignment_id
                    AND TRUNC (curr.cut_off_date) = p_g_sysdate
                 UNION
                 SELECT TRUNC (cut_off_date), past.work_center
                   --FROM cust.ttec_spain_pay_interface_mst past  --code commented by RXNETHI-ARGANO,16/05/23
                   FROM apps.ttec_spain_pay_interface_mst past    --code added by RXNETHI-ARGANO,16/05/23
                  WHERE past.person_id = p_person_id
                    AND past.assignment_id = p_assignment_id
                    AND TRUNC (past.cut_off_date) =
                           (SELECT MAX (TRUNC (cut_off_date))
                              --FROM cust.ttec_spain_pay_interface_mst --code commented by RXNETHI-ARGANO,16/05/23
                              FROM apps.ttec_spain_pay_interface_mst   --code added by RXNETHI-ARGANO,16/05/23
                             WHERE person_id = p_person_id
                               AND assignment_id = p_assignment_id
                               AND TRUNC (cut_off_date) < p_g_sysdate)) a;

-- Ken Mod 7/18/05 added to recognize change for modelo_de_referencia (paaf.ass_attribute10)
      CURSOR modelo_de_cur
      IS
         SELECT NVL (a.modelo_de_referencia, 'X')
           FROM (SELECT TRUNC (cut_off_date), curr.modelo_de_referencia
                   --FROM cust.ttec_spain_pay_interface_mst curr  --code commented by RXNETHI-ARGANO,16/05/23
                   FROM apps.ttec_spain_pay_interface_mst curr    --code added by RXNETHI-ARGANO,16/05/23
                  WHERE curr.person_id = p_person_id
                    AND curr.assignment_id = p_assignment_id
                    AND TRUNC (curr.cut_off_date) = p_g_sysdate
                 UNION
                 SELECT TRUNC (cut_off_date), past.modelo_de_referencia
                   --FROM cust.ttec_spain_pay_interface_mst past  --code commented by RXNETHI-ARGANO,16/05/23
                   FROM apps.ttec_spain_pay_interface_mst past    --code added by RXNETHI-ARGANO,16/05/23
                  WHERE past.person_id = p_person_id
                    AND past.assignment_id = p_assignment_id
                    AND TRUNC (past.cut_off_date) =
                           (SELECT MAX (TRUNC (cut_off_date))
                              --FROM cust.ttec_spain_pay_interface_mst  --code commented by RXNETHI-ARGANO,16/05/23
                              FROM apps.ttec_spain_pay_interface_mst    --code added by RXNETHI-ARGANO,16/05/23
                             WHERE person_id = p_person_id
                               AND assignment_id = p_assignment_id
                               AND TRUNC (cut_off_date) < p_g_sysdate)) a;

-- Ken Mod ending..
      CURSOR convenio_cur
      IS
         SELECT NVL (a.convenio, 'X')
           FROM (SELECT TRUNC (cut_off_date), curr.convenio
                   --FROM cust.ttec_spain_pay_interface_mst curr  --code commented by RXNETHI-ARGANO,16/05/23
                   FROM apps.ttec_spain_pay_interface_mst curr    --code added by RXNETHI-ARGANO,16/05/23
                  WHERE curr.person_id = p_person_id
                    AND curr.assignment_id = p_assignment_id
                    AND TRUNC (curr.cut_off_date) = p_g_sysdate
                 UNION
                 SELECT TRUNC (cut_off_date), past.convenio
                   --FROM cust.ttec_spain_pay_interface_mst past  --code commented by RXNETHI-ARGANO,16/05/23
                   FROM apps.ttec_spain_pay_interface_mst past    --code added by RXNETHI-ARGANO,16/05/23
                  WHERE past.person_id = p_person_id
                    AND past.assignment_id = p_assignment_id
                    AND TRUNC (past.cut_off_date) =
                           (SELECT MAX (TRUNC (cut_off_date))
                              --FROM cust.ttec_spain_pay_interface_mst  --code commented by RXNETHI-ARGANO,16/05/23
                              FROM apps.ttec_spain_pay_interface_mst    --code added by RXNETHI-ARGANO,16/05/23
                             WHERE person_id = p_person_id
                               AND assignment_id = p_assignment_id
                               AND TRUNC (cut_off_date) < p_g_sysdate)) a;

      CURSOR epigrafe_cur
      IS
         SELECT NVL (a.epigrafe, 'X')
           FROM (SELECT TRUNC (cut_off_date), curr.epigrafe
                   --FROM cust.ttec_spain_pay_interface_mst curr  --code commented by RXNETHI-ARGANO,16/05/23
                   FROM apps.ttec_spain_pay_interface_mst curr    --code added by RXNETHI-ARGANO,16/05/23
                  WHERE curr.person_id = p_person_id
                    AND curr.assignment_id = p_assignment_id
                    AND TRUNC (curr.cut_off_date) = p_g_sysdate
                 UNION
                 SELECT TRUNC (cut_off_date), past.epigrafe
                   --FROM cust.ttec_spain_pay_interface_mst past  --code commented by RXNETHI-ARGANO,16/05/23
                   FROM apps.ttec_spain_pay_interface_mst past    --code added by RXNETHI-ARGANO,16/05/23
                  WHERE past.person_id = p_person_id
                    AND past.assignment_id = p_assignment_id
                    AND TRUNC (past.cut_off_date) =
                           (SELECT MAX (TRUNC (cut_off_date))
                              --FROM cust.ttec_spain_pay_interface_mst  --code commented by RXNETHI-ARGANO,16/05/23
                              FROM apps.ttec_spain_pay_interface_mst    --code added by RXNETHI-ARGANO,16/05/23
                             WHERE person_id = p_person_id
                               AND assignment_id = p_assignment_id
                               AND TRUNC (cut_off_date) < p_g_sysdate)) a;

      CURSOR grupo_tarifa_cur
      IS
         SELECT NVL (a.grupo_tarifa, 'X')
           FROM (SELECT TRUNC (cut_off_date), curr.grupo_tarifa
                   --FROM cust.ttec_spain_pay_interface_mst curr  --code commented by RXNETHI-ARGANO,16/05/23
                   FROM apps.ttec_spain_pay_interface_mst curr    --code added by RXNETHI-ARGANO,16/05/23
                  WHERE curr.person_id = p_person_id
                    AND curr.assignment_id = p_assignment_id
                    AND TRUNC (curr.cut_off_date) = p_g_sysdate
                 UNION
                 SELECT TRUNC (cut_off_date), past.grupo_tarifa
                   --FROM cust.ttec_spain_pay_interface_mst past  --code commented by RXNETHI-ARGANO,16/05/23
                   FROM apps.ttec_spain_pay_interface_mst past    --code added by RXNETHI-ARGANO,16/05/23
                  WHERE past.person_id = p_person_id
                    AND past.assignment_id = p_assignment_id
                    AND TRUNC (past.cut_off_date) =
                           (SELECT MAX (TRUNC (cut_off_date))
                              --FROM cust.ttec_spain_pay_interface_mst  --code commented by RXNETHI-ARGANO,16/05/23
                              FROM apps.ttec_spain_pay_interface_mst    --code added by RXNETHI-ARGANO,16/05/23
                             WHERE person_id = p_person_id
                               AND assignment_id = p_assignment_id
                               AND TRUNC (cut_off_date) < p_g_sysdate)) a;

      CURSOR clave_percepcion_cur
      IS
         SELECT NVL (a.clave_percepcion, 'X')
           FROM (SELECT TRUNC (cut_off_date), curr.clave_percepcion
                   --FROM cust.ttec_spain_pay_interface_mst curr  --code commented by RXNETHI-ARGANO,16/05/23
                   FROM apps.ttec_spain_pay_interface_mst curr    --code added by RXNETHI-ARGANO,16/05/23
                  WHERE curr.person_id = p_person_id
                    AND curr.assignment_id = p_assignment_id
                    AND TRUNC (curr.cut_off_date) = p_g_sysdate
                 UNION
                 SELECT TRUNC (cut_off_date), past.clave_percepcion
                   --FROM cust.ttec_spain_pay_interface_mst past  --code commented by RXNETHI-ARGANO,16/05/23
                   FROM apps.ttec_spain_pay_interface_mst past    --code added by RXNETHI-ARGANO,16/05/23
                  WHERE past.person_id = p_person_id
                    AND past.assignment_id = p_assignment_id
                    AND TRUNC (past.cut_off_date) =
                           (SELECT MAX (TRUNC (cut_off_date))
                              --FROM cust.ttec_spain_pay_interface_mst   --code commented by RXNETHI-ARGANO,16/05/23
                              FROM apps.ttec_spain_pay_interface_mst     --code added by RXNETHI-ARGANO,16/05/23
                             WHERE person_id = p_person_id
                               AND assignment_id = p_assignment_id
                               AND TRUNC (cut_off_date) < p_g_sysdate)) a;

      CURSOR tax_id_cur
      IS
         SELECT NVL (a.tax_id, 'X')
           FROM (SELECT TRUNC (cut_off_date), curr.tax_id
                   --FROM cust.ttec_spain_pay_interface_mst curr  --code commented by RXNETHI-ARGANO,16/05/23
                   FROM apps.ttec_spain_pay_interface_mst curr    --code added by RXNETHI-ARGANO,16/05/23
                  WHERE curr.person_id = p_person_id
                    AND curr.assignment_id = p_assignment_id
                    AND TRUNC (curr.cut_off_date) = p_g_sysdate
                 UNION
                 SELECT TRUNC (cut_off_date), past.tax_id
                   --FROM cust.ttec_spain_pay_interface_mst past  --code commented by RXNETHI-ARGANO,16/05/23
                   FROM apps.ttec_spain_pay_interface_mst past    --code added by RXNETHI-ARGANO,16/05/23
                  WHERE past.person_id = p_person_id
                    AND past.assignment_id = p_assignment_id
                    AND TRUNC (past.cut_off_date) =
                           (SELECT MAX (TRUNC (cut_off_date))
                              --FROM cust.ttec_spain_pay_interface_mst  --code commented by RXNETHI-ARGANO,16/05/23
                              FROM apps.ttec_spain_pay_interface_mst    --code added by RXNETHI-ARGANO,16/05/23
                             WHERE person_id = p_person_id
                               AND assignment_id = p_assignment_id
                               AND TRUNC (cut_off_date) < p_g_sysdate)) a;

      CURSOR date_start_cur
      IS
         SELECT NVL (a.date_start, 'X')
           FROM (SELECT TRUNC (cut_off_date), curr.date_start
                   --FROM cust.ttec_spain_pay_interface_mst curr  --code commented by RXNETHI-ARGANO,16/05/23
                   FROM apps.ttec_spain_pay_interface_mst curr    --code added by RXNETHI-ARGANO,16/05/23
                  WHERE curr.person_id = p_person_id
                    AND curr.assignment_id = p_assignment_id
                    AND TRUNC (curr.cut_off_date) = p_g_sysdate
                 UNION
                 SELECT TRUNC (cut_off_date), past.date_start
                   --FROM cust.ttec_spain_pay_interface_mst past  --code commented by RXNETHI-ARGANO,16/05/23
                   FROM apps.ttec_spain_pay_interface_mst past    --code added by RXNETHI-ARGANO,16/05/23
                  WHERE past.person_id = p_person_id
                    AND past.assignment_id = p_assignment_id
                    AND TRUNC (past.cut_off_date) =
                           (SELECT MAX (TRUNC (cut_off_date))
                              --FROM cust.ttec_spain_pay_interface_mst  --code commented by RXNETHI-ARGANO,16/05/23
                              FROM apps.ttec_spain_pay_interface_mst    --code added by RXNETHI-ARGANO,16/05/23
                             WHERE person_id = p_person_id
                               AND assignment_id = p_assignment_id
                               AND TRUNC (cut_off_date) < p_g_sysdate)) a;

      CURSOR tipo_salario_cur
      IS
         SELECT NVL (a.tipo_salario, 'X')
           FROM (SELECT TRUNC (cut_off_date), curr.tipo_salario
                   --FROM cust.ttec_spain_pay_interface_mst curr  --code commented by RXNETHI-ARGANO,16/05/23
                   FROM apps.ttec_spain_pay_interface_mst curr    --code added by RXNETHI-ARGANO,16/05/23
                  WHERE curr.person_id = p_person_id
                    AND curr.assignment_id = p_assignment_id
                    AND TRUNC (curr.cut_off_date) = p_g_sysdate
                 UNION
                 SELECT TRUNC (cut_off_date), past.tipo_salario
                   --FROM cust.ttec_spain_pay_interface_mst past  --code commented by RXNETHI-ARGANO,16/05/23
                   FROM apps.ttec_spain_pay_interface_mst past    --code added by RXNETHI-ARGANO,16/05/23
                  WHERE past.person_id = p_person_id
                    AND past.assignment_id = p_assignment_id
                    AND TRUNC (past.cut_off_date) =
                           (SELECT MAX (TRUNC (cut_off_date))
                              --FROM cust.ttec_spain_pay_interface_mst  --code commented by RXNETHI-ARGANO,16/05/23
                              FROM apps.ttec_spain_pay_interface_mst    --code added by RXNETHI-ARGANO,16/05/23
                             WHERE person_id = p_person_id
                               AND assignment_id = p_assignment_id
                               AND TRUNC (cut_off_date) < p_g_sysdate)) a;

      CURSOR tipo_de_ajuste_cur
      IS
         SELECT NVL (a.tipo_de_ajuste, 'X')
           FROM (SELECT TRUNC (cut_off_date), curr.tipo_de_ajuste
                   --FROM cust.ttec_spain_pay_interface_mst curr  --code commented by RXNETHI-ARGANO,16/05/23
                   FROM apps.ttec_spain_pay_interface_mst curr    --code added by RXNETHI-ARGANO,16/05/23
                  WHERE curr.person_id = p_person_id
                    AND curr.assignment_id = p_assignment_id
                    AND TRUNC (curr.cut_off_date) = p_g_sysdate
                 UNION
                 SELECT TRUNC (cut_off_date), past.tipo_de_ajuste
                   --FROM cust.ttec_spain_pay_interface_mst past  --code commented by RXNETHI-ARGANO,16/05/23
                   FROM apps.ttec_spain_pay_interface_mst past    --code added by RXNETHI-ARGANO,16/05/23
                  WHERE past.person_id = p_person_id
                    AND past.assignment_id = p_assignment_id
                    AND TRUNC (past.cut_off_date) =
                           (SELECT MAX (TRUNC (cut_off_date))
                              --FROM cust.ttec_spain_pay_interface_mst  --code commented by RXNETHI-ARGANO,16/05/23
                              FROM apps.ttec_spain_pay_interface_mst    --code added by RXNETHI-ARGANO,16/05/23
                             WHERE person_id = p_person_id
                               AND assignment_id = p_assignment_id
                               AND TRUNC (cut_off_date) < p_g_sysdate)) a;

--===========================
      CURSOR job_id_cur
      IS
         SELECT NVL (a.job_id, 'X')
           FROM (SELECT TRUNC (cut_off_date), curr.job_id
                   --FROM cust.ttec_spain_pay_interface_mst curr  --code commented by RXNETHI-ARGANO,16/05/23
                   FROM apps.ttec_spain_pay_interface_mst curr    --code added by RXNETHI-ARGANO,16/05/23
                  WHERE curr.person_id = p_person_id
                    AND curr.assignment_id = p_assignment_id
                    AND TRUNC (curr.cut_off_date) = p_g_sysdate
                 UNION
                 SELECT TRUNC (cut_off_date), past.job_id
                   --FROM cust.ttec_spain_pay_interface_mst past  --code commented by RXNETHI-ARGANO,16/05/23
                   FROM apps.ttec_spain_pay_interface_mst past    --code added by RXNETHI-ARGANO,16/05/23
                  WHERE past.person_id = p_person_id
                    AND past.assignment_id = p_assignment_id
                    AND TRUNC (past.cut_off_date) =
                           (SELECT MAX (TRUNC (cut_off_date))
                              --FROM cust.ttec_spain_pay_interface_mst  --code commented by RXNETHI-ARGANO,16/05/23
                              FROM apps.ttec_spain_pay_interface_mst    --code added by RXNETHI-ARGANO,16/05/23
                             WHERE person_id = p_person_id
                               AND assignment_id = p_assignment_id
                               AND TRUNC (cut_off_date) < p_g_sysdate)) a;

      CURSOR new_job_id_cur
      IS
         SELECT NVL (a.new_job_id, 'X')
           FROM (SELECT TRUNC (cut_off_date), curr.new_job_id
                   --FROM cust.ttec_spain_pay_interface_mst curr
                   FROM apps.ttec_spain_pay_interface_mst curr
                  WHERE curr.person_id = p_person_id
                    AND curr.assignment_id = p_assignment_id
                    AND TRUNC (curr.cut_off_date) = p_g_sysdate
                 UNION
                 SELECT TRUNC (cut_off_date), past.new_job_id
                   --FROM cust.ttec_spain_pay_interface_mst past --code commented by RXNETHI-ARGANO,16/05/23
                   FROM apps.ttec_spain_pay_interface_mst past   --code added by RXNETHI-ARGANO,16/05/23
                  WHERE past.person_id = p_person_id
                    AND past.assignment_id = p_assignment_id
                    AND TRUNC (past.cut_off_date) =
                           (SELECT MAX (TRUNC (cut_off_date))
                              --FROM cust.ttec_spain_pay_interface_mst --code commented by RXNETHI-ARGANO,16/05/23
                              FROM apps.ttec_spain_pay_interface_mst   --code added by RXNETHI-ARGANO,16/05/23
                             WHERE person_id = p_person_id
                               AND assignment_id = p_assignment_id
                               AND TRUNC (cut_off_date) < p_g_sysdate)) a;

      CURSOR departmento_cur
      IS
         SELECT NVL (a.departmento, 'X')
           FROM (SELECT TRUNC (cut_off_date), curr.departmento
                   --FROM cust.ttec_spain_pay_interface_mst curr  --code commented by RXNETHI-ARGANO,16/05/23
                   FROM apps.ttec_spain_pay_interface_mst curr    --code added by RXNETHI-ARGANO,16/05/23
                  WHERE curr.person_id = p_person_id
                    AND curr.assignment_id = p_assignment_id
                    AND TRUNC (curr.cut_off_date) = p_g_sysdate
                 UNION
                 SELECT TRUNC (cut_off_date), past.departmento
                   --FROM cust.ttec_spain_pay_interface_mst past --code commented by RXNETHI-ARGANO,16/05/23
                   FROM apps.ttec_spain_pay_interface_mst past   --code added by RXNETHI-ARGANO,16/05/23
                  WHERE past.person_id = p_person_id
                    AND past.assignment_id = p_assignment_id
                    AND TRUNC (past.cut_off_date) =
                           (SELECT MAX (TRUNC (cut_off_date))
                              --FROM cust.ttec_spain_pay_interface_mst  --code commented by RXNETHI-ARGANO,16/05/23
                              FROM apps.ttec_spain_pay_interface_mst    --code added by RXNETHI-ARGANO,16/05/23
                             WHERE person_id = p_person_id
                               AND assignment_id = p_assignment_id
                               AND TRUNC (cut_off_date) < p_g_sysdate)) a;

      CURSOR centro_de_trabajo_cur
      IS
         SELECT NVL (a.centro_de_trabajo, 'X')
           FROM (SELECT TRUNC (cut_off_date), curr.centro_de_trabajo
                   --FROM cust.ttec_spain_pay_interface_mst curr  --code commented by RXNETHI-ARGANO,16/05/23
                   FROM apps.ttec_spain_pay_interface_mst curr    --code added by RXNETHI-ARGANO,16/05/23
                  WHERE curr.person_id = p_person_id
                    AND curr.assignment_id = p_assignment_id
                    AND TRUNC (curr.cut_off_date) = p_g_sysdate
                 UNION
                 SELECT TRUNC (cut_off_date), past.centro_de_trabajo
                   --FROM cust.ttec_spain_pay_interface_mst past  --code commented by RXNETHI-ARGANO,16/05/23
                   FROM apps.ttec_spain_pay_interface_mst past    --code added by RXNETHI-ARGANO,16/05/23
                  WHERE past.person_id = p_person_id
                    AND past.assignment_id = p_assignment_id
                    AND TRUNC (past.cut_off_date) =
                           (SELECT MAX (TRUNC (cut_off_date))
                              --FROM cust.ttec_spain_pay_interface_mst  --code commented by RXNETHI-ARGANO,16/05/23
                              FROM apps.ttec_spain_pay_interface_mst    --code added by RXNETHI-ARGANO,16/05/23
                             WHERE person_id = p_person_id
                               AND assignment_id = p_assignment_id
                               AND TRUNC (cut_off_date) < p_g_sysdate)) a;

      CURSOR salary_change_date_cur
      IS
         SELECT NVL (a.salary_change_date, 'X')
           FROM (SELECT TRUNC (cut_off_date), curr.salary_change_date
                   --FROM cust.ttec_spain_pay_interface_mst curr  --code commented by RXNETHI-ARGANO,16/05/23
                   FROM apps.ttec_spain_pay_interface_mst curr    --code added by RXNETHI-ARGANO,16/05/23
                  WHERE curr.person_id = p_person_id
                    AND curr.assignment_id = p_assignment_id
                    AND TRUNC (curr.cut_off_date) = p_g_sysdate
                 UNION
                 SELECT TRUNC (cut_off_date), past.salary_change_date
                   --FROM cust.ttec_spain_pay_interface_mst past  --code commented by RXNETHI-ARGANO,16/05/23
                   FROM apps.ttec_spain_pay_interface_mst past    --code added by RXNETHI-ARGANO,16/05/23
                  WHERE past.person_id = p_person_id
                    AND past.assignment_id = p_assignment_id
                    AND TRUNC (past.cut_off_date) =
                           (SELECT MAX (TRUNC (cut_off_date))
                              --FROM cust.ttec_spain_pay_interface_mst  --code commented by RXNETHI-ARGANO,16/05/23
                              FROM apps.ttec_spain_pay_interface_mst    --code added by RXNETHI-ARGANO,16/05/23
                             WHERE person_id = p_person_id
                               AND assignment_id = p_assignment_id
                               AND TRUNC (cut_off_date) < p_g_sysdate)) a;

      CURSOR nivel_salarial_cur
      IS
         SELECT NVL (a.nivel_salarial, 'X')
           FROM (SELECT TRUNC (cut_off_date), curr.nivel_salarial
                   --FROM cust.ttec_spain_pay_interface_mst curr --code commented by RXNETHI-ARGANO,16/05/23
                   FROM apps.ttec_spain_pay_interface_mst curr   --code added by RXNETHI-ARGANO,16/05/23
                  WHERE curr.person_id = p_person_id
                    AND curr.assignment_id = p_assignment_id
                    AND TRUNC (curr.cut_off_date) = p_g_sysdate
                 UNION
                 SELECT TRUNC (cut_off_date), past.nivel_salarial
                   --FROM cust.ttec_spain_pay_interface_mst past --code commented by RXNETHI-ARGANO,16/05/23
                   FROM apps.ttec_spain_pay_interface_mst past   --code added by RXNETHI-ARGANO,16/05/23
                  WHERE past.person_id = p_person_id
                    AND past.assignment_id = p_assignment_id
                    AND TRUNC (past.cut_off_date) =
                           (SELECT MAX (TRUNC (cut_off_date))
                              --FROM cust.ttec_spain_pay_interface_mst  --code commented by RXNETHI-ARGANO,16/05/23
                              FROM apps.ttec_spain_pay_interface_mst    --code added by RXNETHI-ARGANO,16/05/23
                             WHERE person_id = p_person_id
                               AND assignment_id = p_assignment_id
                               AND TRUNC (cut_off_date) < p_g_sysdate)) a;

      CURSOR salary_cur
      IS
         SELECT NVL (a.salary, 'X')
           FROM (SELECT TRUNC (cut_off_date), curr.salary
                   --FROM cust.ttec_spain_pay_interface_mst curr  --code commented by RXNETHI-ARGANO,16/05/23
                   FROM apps.ttec_spain_pay_interface_mst curr    --code added by RXNETHI-ARGANO,16/05/23
                  WHERE curr.person_id = p_person_id
                    AND curr.assignment_id = p_assignment_id
                    AND TRUNC (curr.cut_off_date) = p_g_sysdate
                 UNION
                 SELECT TRUNC (cut_off_date), past.salary
                   --FROM cust.ttec_spain_pay_interface_mst past  --code commented by RXNETHI-ARGANO,16/05/23
                   FROM apps.ttec_spain_pay_interface_mst past    --code added by RXNETHI-ARGANO,16/05/23
                  WHERE past.person_id = p_person_id
                    AND past.assignment_id = p_assignment_id
                    AND TRUNC (past.cut_off_date) =
                           (SELECT MAX (TRUNC (cut_off_date))
                              --FROM cust.ttec_spain_pay_interface_mst  --code commented by RXNETHI-ARGANO,16/05/23
                              FROM apps.ttec_spain_pay_interface_mst    --code added by RXNETHI-ARGANO,16/05/23
                             WHERE person_id = p_person_id
                               AND assignment_id = p_assignment_id
                               AND TRUNC (cut_off_date) < p_g_sysdate)) a;

      CURSOR centros_de_coste_cur
      IS
         SELECT NVL (a.centros_de_coste, 'X')
           FROM (SELECT TRUNC (cut_off_date), curr.centros_de_coste
                   --FROM cust.ttec_spain_pay_interface_mst curr  --code commented by RXNETHI-ARGANO,16/05/23
                   FROM apps.ttec_spain_pay_interface_mst curr    --code added by RXNETHI-ARGANO,16/05/23
                  WHERE curr.person_id = p_person_id
                    AND curr.assignment_id = p_assignment_id
                    AND TRUNC (curr.cut_off_date) = p_g_sysdate
                 UNION
                 SELECT TRUNC (cut_off_date), past.centros_de_coste
                   --FROM cust.ttec_spain_pay_interface_mst past  --code commented by RXNETHI-ARGANO,16/05/23
                   FROM apps.ttec_spain_pay_interface_mst past    --code added by RXNETHI-ARGANO,16/05/23
                  WHERE past.person_id = p_person_id
                    AND past.assignment_id = p_assignment_id
                    AND TRUNC (past.cut_off_date) =
                           (SELECT MAX (TRUNC (cut_off_date))
                              --FROM cust.ttec_spain_pay_interface_mst  --code commented by RXNETHI-ARGANO,16/05/23
                              FROM apps.ttec_spain_pay_interface_mst    --code added by RXNETHI-ARGANO,16/05/23
                             WHERE person_id = p_person_id
                               AND assignment_id = p_assignment_id
                               AND TRUNC (cut_off_date) < p_g_sysdate)) a;

----=======================
      CURSOR bank_name_cur
      IS
         SELECT NVL (a.bank_name, 'X')
           FROM (SELECT TRUNC (cut_off_date), curr.bank_name
                   --FROM cust.ttec_spain_pay_interface_mst curr  --code commented by RXNETHI-ARGANO,16/05/23
                   FROM apps.ttec_spain_pay_interface_mst curr    --code added by RXNETHI-ARGANO,16/05/23
                  WHERE curr.person_id = p_person_id
                    AND curr.assignment_id = p_assignment_id
                    AND TRUNC (curr.cut_off_date) = p_g_sysdate
                 UNION
                 SELECT TRUNC (cut_off_date), past.bank_name
                   --FROM cust.ttec_spain_pay_interface_mst past  --code commented by RXNETHI-ARGANO,16/05/23
                   FROM apps.ttec_spain_pay_interface_mst past    --code added by RXNETHI-ARGANO,16/05/23
                  WHERE past.person_id = p_person_id
                    AND past.assignment_id = p_assignment_id
                    AND TRUNC (past.cut_off_date) =
                           (SELECT MAX (TRUNC (cut_off_date))
                              --FROM cust.ttec_spain_pay_interface_mst  --code commented by RXNETHI-ARGANO,16/05/23
                              FROM apps.ttec_spain_pay_interface_mst    --code added by RXNETHI-ARGANO,16/05/23
                             WHERE person_id = p_person_id
                               AND assignment_id = p_assignment_id
                               AND TRUNC (cut_off_date) < p_g_sysdate)) a;

      CURSOR bank_branch_cur
      IS
         SELECT NVL (a.bank_branch, 'X')
           FROM (SELECT TRUNC (cut_off_date), curr.bank_branch
                   --FROM cust.ttec_spain_pay_interface_mst curr  --code commented by RXNETHI-ARGANO,16/05/23
                   FROM apps.ttec_spain_pay_interface_mst curr    --code added by RXNETHI-ARGANO,16/05/23
                  WHERE curr.person_id = p_person_id
                    AND curr.assignment_id = p_assignment_id
                    AND TRUNC (curr.cut_off_date) = p_g_sysdate
                 UNION
                 SELECT TRUNC (cut_off_date), past.bank_branch
                   --FROM cust.ttec_spain_pay_interface_mst past  --code commented by RXNETHI-ARGANO,16/05/23
                   FROM apps.ttec_spain_pay_interface_mst past    --code added by RXNETHI-ARGANO,16/05/23
                  WHERE past.person_id = p_person_id
                    AND past.assignment_id = p_assignment_id
                    AND TRUNC (past.cut_off_date) =
                           (SELECT MAX (TRUNC (cut_off_date))
                              --FROM cust.ttec_spain_pay_interface_mst  --code commented by RXNETHI-ARGANO,16/05/23
                              FROM apps.ttec_spain_pay_interface_mst    --code added by RXNETHI-ARGANO,16/05/23
                             WHERE person_id = p_person_id
                               AND assignment_id = p_assignment_id
                               AND TRUNC (cut_off_date) < p_g_sysdate)) a;

      CURSOR account_number_cur
      IS
         SELECT NVL (a.account_number, 'X')
           FROM (SELECT TRUNC (cut_off_date), curr.account_number
                   --FROM cust.ttec_spain_pay_interface_mst curr  --code commented by RXNETHI-ARGANO,16/05/23
                   FROM apps.ttec_spain_pay_interface_mst curr    --code added by RXNETHI-ARGANO,16/05/23
                  WHERE curr.person_id = p_person_id
                    AND curr.assignment_id = p_assignment_id
                    AND TRUNC (curr.cut_off_date) = p_g_sysdate
                 UNION
                 SELECT TRUNC (cut_off_date), past.account_number
                   --FROM cust.ttec_spain_pay_interface_mst past  --code commented by RXNETHI-ARGANO,16/05/23
                   FROM apps.ttec_spain_pay_interface_mst past    --code added by RXNETHI-ARGANO,16/05/23
                  WHERE past.person_id = p_person_id
                    AND past.assignment_id = p_assignment_id
                    AND TRUNC (past.cut_off_date) =
                           (SELECT MAX (TRUNC (cut_off_date))
                              --FROM cust.ttec_spain_pay_interface_mst  --code commented by RXNETHI-ARGANO,16/05/23
                              FROM apps.ttec_spain_pay_interface_mst    --code added by RXNETHI-ARGANO,16/05/23
                             WHERE person_id = p_person_id
                               AND assignment_id = p_assignment_id
                               AND TRUNC (cut_off_date) < p_g_sysdate)) a;

      CURSOR control_id_cur
      IS
         SELECT NVL (a.control_id, 'X')
           FROM (SELECT TRUNC (cut_off_date), curr.control_id
                   --FROM cust.ttec_spain_pay_interface_mst curr  --code commented by RXNETHI-ARGANO,16/05/23
                   FROM apps.ttec_spain_pay_interface_mst curr    --code added by RXNETHI-ARGANO,16/05/23
                  WHERE curr.person_id = p_person_id
                    AND curr.assignment_id = p_assignment_id
                    AND TRUNC (curr.cut_off_date) = p_g_sysdate
                 UNION
                 SELECT TRUNC (cut_off_date), past.control_id
                   --FROM cust.ttec_spain_pay_interface_mst past  --code commented by RXNETHI-ARGANO,16/05/23
                   FROM apps.ttec_spain_pay_interface_mst past    --code added by RXNETHI-ARGANO,16/05/23
                  WHERE past.person_id = p_person_id
                    AND past.assignment_id = p_assignment_id
                    AND TRUNC (past.cut_off_date) =
                           (SELECT MAX (TRUNC (cut_off_date))
                              --FROM cust.ttec_spain_pay_interface_mst  --code commented by RXNETHI-ARGANO,16/05/23
                              FROM apps.ttec_spain_pay_interface_mst  --code added by RXNETHI-ARGANO,16/05/23
                             WHERE person_id = p_person_id
                               AND assignment_id = p_assignment_id
                               AND TRUNC (cut_off_date) < p_g_sysdate)) a;

      CURSOR system_person_type_cur
      IS
         SELECT NVL (a.system_person_type, 'X')
           FROM (SELECT TRUNC (cut_off_date), curr.system_person_type
                   --FROM cust.ttec_spain_pay_interface_mst curr  --code commented by RXNETHI-ARGANO,16/05/23
                   FROM apps.ttec_spain_pay_interface_mst curr    --code added by RXNETHI-ARGANO,16/05/23
                  WHERE curr.person_id = p_person_id
                    AND curr.assignment_id = p_assignment_id
                    AND TRUNC (curr.cut_off_date) = p_g_sysdate
                 UNION
                 SELECT TRUNC (cut_off_date), past.system_person_type
                   --FROM cust.ttec_spain_pay_interface_mst past  --code commented by RXNETHI-ARGANO,16/05/23
                   FROM apps.ttec_spain_pay_interface_mst past    --code added by RXNETHI-ARGANO,16/05/23
                  WHERE past.person_id = p_person_id
                    AND past.assignment_id = p_assignment_id
                    AND TRUNC (past.cut_off_date) =
                           (SELECT MAX (TRUNC (cut_off_date))
                              --FROM cust.ttec_spain_pay_interface_mst  --code commented by RXNETHI-ARGANO,16/05/23
                              FROM apps.ttec_spain_pay_interface_mst    --code added by RXNETHI-ARGANO,16/05/23
                             WHERE person_id = p_person_id
                               AND assignment_id = p_assignment_id
                               AND TRUNC (cut_off_date) < p_g_sysdate)) a;

      CURSOR fecha_fin_contrato_cur
      IS
         SELECT NVL (a.fecha_fin_contrato, 'X')
           FROM (SELECT TRUNC (cut_off_date), curr.fecha_fin_contrato
                   --FROM cust.ttec_spain_pay_interface_mst curr  --code commented by RXNETHI-ARGANO,16/05/23
                   FROM apps.ttec_spain_pay_interface_mst curr    --code added by RXNETHI-ARGANO,16/05/23
                  WHERE curr.person_id = p_person_id
                    AND curr.assignment_id = p_assignment_id
                    AND TRUNC (curr.cut_off_date) = p_g_sysdate
                 UNION
                 SELECT TRUNC (cut_off_date), past.fecha_fin_contrato
                   --FROM cust.ttec_spain_pay_interface_mst past  --code commented by RXNETHI-ARGANO,16/05/23
                   FROM apps.ttec_spain_pay_interface_mst past    --code added by RXNETHI-ARGANO,16/05/23
                  WHERE past.person_id = p_person_id
                    AND past.assignment_id = p_assignment_id
                    AND TRUNC (past.cut_off_date) =
                           (SELECT MAX (TRUNC (cut_off_date))
                              --FROM cust.ttec_spain_pay_interface_mst  --code commented by RXNETHI-ARGANO,16/05/23
                              FROM apps.ttec_spain_pay_interface_mst    --code added by RXNETHI-ARGANO,16/05/23
                             WHERE person_id = p_person_id
                               AND assignment_id = p_assignment_id
                               AND TRUNC (cut_off_date) < p_g_sysdate)) a;

-- C. Chan Mod 9/23/05 to track changes of Fecha_fin_prevista field
      CURSOR fecha_fin_prevista_cur
      IS
         SELECT NVL (a.fecha_fin_prevista, 'X')
           FROM (SELECT TRUNC (cut_off_date), curr.fecha_fin_prevista
                   --FROM cust.ttec_spain_pay_interface_mst curr  --code commented by RXNETHI-ARGANO,16/05/23
                   FROM apps.ttec_spain_pay_interface_mst curr    --code added by RXNETHI-ARGANO,16/05/23
                  WHERE curr.person_id = p_person_id
                    AND curr.assignment_id = p_assignment_id
                    AND TRUNC (curr.cut_off_date) = p_g_sysdate
                 UNION
                 SELECT TRUNC (cut_off_date), past.fecha_fin_prevista
                   --FROM cust.ttec_spain_pay_interface_mst past  --code commented by RXNETHI-ARGANO,16/05/23
                   FROM apps.ttec_spain_pay_interface_mst past    --code added by RXNETHI-ARGANO,16/05/23
                  WHERE past.person_id = p_person_id
                    AND past.assignment_id = p_assignment_id
                    AND TRUNC (past.cut_off_date) =
                           (SELECT MAX (TRUNC (cut_off_date))
                              --FROM cust.ttec_spain_pay_interface_mst  --code commented by RXNETHI-ARGANO,16/05/23
                              FROM apps.ttec_spain_pay_interface_mst    --code added by RXNETHI-ARGANO,16/05/23
                             WHERE person_id = p_person_id
                               AND assignment_id = p_assignment_id
                               AND TRUNC (cut_off_date) < p_g_sysdate)) a;

-- Added by CC on 3/14/2006 was missing previouly
      CURSOR ass_eff_date_cur
      IS
         SELECT NVL (a.ass_eff_date, 'X')
           FROM (SELECT TRUNC (cut_off_date), curr.ass_eff_date
                   --FROM cust.ttec_spain_pay_interface_mst curr  --code commented by RXNETHI-ARGANO,16/05/23
                   FROM apps.ttec_spain_pay_interface_mst curr    --code added by RXNETHI-ARGANO,16/05/23
                  WHERE curr.person_id = p_person_id
                    AND curr.assignment_id = p_assignment_id
                    AND TRUNC (curr.cut_off_date) = p_g_sysdate
                 UNION
                 SELECT TRUNC (cut_off_date), past.ass_eff_date
                   --FROM cust.ttec_spain_pay_interface_mst past  --code commented by RXNETHI-ARGANO,16/05/23
                   FROM apps.ttec_spain_pay_interface_mst past    --code added by RXNETHI-ARGANO,16/05/23
                  WHERE past.person_id = p_person_id
                    AND past.assignment_id = p_assignment_id
                    AND TRUNC (past.cut_off_date) =
                           (SELECT MAX (TRUNC (cut_off_date))
                              --FROM cust.ttec_spain_pay_interface_mst  --code commented by RXNETHI-ARGANO,16/05/23
                              FROM apps.ttec_spain_pay_interface_mst    --code added by RXNETHI-ARGANO,16/05/23
                             WHERE person_id = p_person_id
                               AND assignment_id = p_assignment_id
                               AND TRUNC (cut_off_date) < p_g_sysdate)) a;

-- Ken Mod 8/12/05 to track changes of Fecha_fin_periodo field
      CURSOR fecha_fin_periodo_cur
      IS
         SELECT NVL (a.fecha_fin_periodo, 'X')
           FROM (SELECT TRUNC (cut_off_date), curr.fecha_fin_periodo
                   --FROM cust.ttec_spain_pay_interface_mst curr  --code commented by RXNETHI-ARGANO,16/05/23
                   FROM apps.ttec_spain_pay_interface_mst curr    --code added by RXNETHI-ARGANO,16/05/23
                  WHERE curr.person_id = p_person_id
                    AND curr.assignment_id = p_assignment_id
                    AND TRUNC (curr.cut_off_date) = p_g_sysdate
                 UNION
                 SELECT TRUNC (cut_off_date), past.fecha_fin_periodo
                   --FROM cust.ttec_spain_pay_interface_mst past  --code commented by RXNETHI-ARGANO,16/05/23
                   FROM apps.ttec_spain_pay_interface_mst past    --code added by RXNETHI-ARGANO,16/05/23
                  WHERE past.person_id = p_person_id
                    AND past.assignment_id = p_assignment_id
                    AND TRUNC (past.cut_off_date) =
                           (SELECT MAX (TRUNC (cut_off_date))
                              --FROM cust.ttec_spain_pay_interface_mst  --code commented by RXNETHI-ARGANO,16/05/23
                              FROM apps.ttec_spain_pay_interface_mst    --code added by RXNETHI-ARGANO,16/05/23
                             WHERE person_id = p_person_id
                               AND assignment_id = p_assignment_id
                               AND TRUNC (cut_off_date) < p_g_sysdate)) a;

-- Ken Mod 8/29/05 to track changes of Fecha_Inicio_Bonificacion and Fecha_Fin_Bonificacion fields
      CURSOR fecha_inicio_bonificacion_cur
      IS
         SELECT NVL (a.fecha_inicio_bonificacion, 'X')
           FROM (SELECT TRUNC (cut_off_date), curr.fecha_inicio_bonificacion
                   --FROM cust.ttec_spain_pay_interface_mst curr  --code commented by RXNETHI-ARGANO,16/05/23
                   FROM apps.ttec_spain_pay_interface_mst curr    --code added by RXNETHI-ARGANO,16/05/23
                  WHERE curr.person_id = p_person_id
                    AND curr.assignment_id = p_assignment_id
                    AND TRUNC (curr.cut_off_date) = p_g_sysdate
                 UNION
                 SELECT TRUNC (cut_off_date), past.fecha_inicio_bonificacion
                   --FROM cust.ttec_spain_pay_interface_mst past  --code commented by RXNETHI-ARGANO,16/05/23
                   FROM apps.ttec_spain_pay_interface_mst past    --code added by RXNETHI-ARGANO,16/05/23
                  WHERE past.person_id = p_person_id
                    AND past.assignment_id = p_assignment_id
                    AND TRUNC (past.cut_off_date) =
                           (SELECT MAX (TRUNC (cut_off_date)) 
                              --FROM cust.ttec_spain_pay_interface_mst  --code commented by RXNETHI-ARGANO,16/05/23
                              FROM apps.ttec_spain_pay_interface_mst    --code added by RXNETHI-ARGANO,16/05/23
                             WHERE person_id = p_person_id
                               AND assignment_id = p_assignment_id
                               AND TRUNC (cut_off_date) < p_g_sysdate)) a;

      CURSOR fecha_fin_bonificacion_cur
      IS
         SELECT NVL (a.fecha_fin_bonificacion, 'X')
           FROM (SELECT TRUNC (cut_off_date), curr.fecha_fin_bonificacion
                   --FROM cust.ttec_spain_pay_interface_mst curr  --code commented by RXNETHI-ARGANO,16/05/23
                   FROM apps.ttec_spain_pay_interface_mst curr    --code added by RXNETHI-ARGANO,16/05/23
                  WHERE curr.person_id = p_person_id
                    AND curr.assignment_id = p_assignment_id
                    AND TRUNC (curr.cut_off_date) = p_g_sysdate
                 UNION
                 SELECT TRUNC (cut_off_date), past.fecha_fin_bonificacion
                   --FROM cust.ttec_spain_pay_interface_mst past  --code commented by RXNETHI-ARGANO,16/05/23
                   FROM apps.ttec_spain_pay_interface_mst past    --code added by RXNETHI-ARGANO,16/05/23
                  WHERE past.person_id = p_person_id
                    AND past.assignment_id = p_assignment_id
                    AND TRUNC (past.cut_off_date) =
                           (SELECT MAX (TRUNC (cut_off_date))
                              --FROM cust.ttec_spain_pay_interface_mst  --code commented by RXNETHI-ARGANO,16/05/23
                              FROM apps.ttec_spain_pay_interface_mst    --code added by RXNETHI-ARGANO,16/05/23
                             WHERE person_id = p_person_id
                               AND assignment_id = p_assignment_id
                               AND TRUNC (cut_off_date) < p_g_sysdate)) a;

      CURSOR legal_employer_cur
      IS
         SELECT NVL (a.legal_employer, 'X')
           FROM (SELECT TRUNC (cut_off_date), curr.legal_employer
                   --FROM cust.ttec_spain_pay_interface_mst curr  --code commented by RXNETHI-ARGANO,16/05/23
                   FROM apps.ttec_spain_pay_interface_mst curr    --code added by RXNETHI-ARGANO,16/05/23
                  WHERE curr.person_id = p_person_id
                    AND curr.assignment_id = p_assignment_id
                    AND TRUNC (curr.cut_off_date) = p_g_sysdate
                 UNION
                 SELECT TRUNC (cut_off_date), past.legal_employer
                   --FROM cust.ttec_spain_pay_interface_mst past  --code commented by RXNETHI-ARGANO,16/05/23
                   FROM apps.ttec_spain_pay_interface_mst past    --code added by RXNETHI-ARGANO,16/05/23
                  WHERE past.person_id = p_person_id
                    AND past.assignment_id = p_assignment_id
                    AND TRUNC (past.cut_off_date) =
                           (SELECT MAX (TRUNC (cut_off_date))
                              --FROM cust.ttec_spain_pay_interface_mst  --code commented by RXNETHI-ARGANO,16/05/23
                              FROM apps.ttec_spain_pay_interface_mst    --code added by RXNETHI-ARGANO,16/05/23
                             WHERE person_id = p_person_id
                               AND assignment_id = p_assignment_id
                               AND TRUNC (cut_off_date) < p_g_sysdate)) a;

-- Ken Mod 8/29/05 ending...
      i                      BINARY_INTEGER := 0;
      l_v_index              BINARY_INTEGER;
      l_v_value_to_compare   VARCHAR2 (240);

      TYPE v_rectabtype IS TABLE OF VARCHAR2 (240)
         INDEX BY BINARY_INTEGER;

      v_records_table        v_rectabtype;
      l_record_changed       VARCHAR2 (1)   := 'N';
      l_v_record_count       NUMBER         := 0;
   BEGIN
      IF p_column_name = 'LAST_NAME'
      THEN
         OPEN last_name_cur;

         LOOP
            i := i + 1;

            FETCH last_name_cur
             INTO v_records_table (i);

            EXIT WHEN last_name_cur%NOTFOUND;
         END LOOP;
      ELSIF p_column_name = 'SECOND_LAST_NAME'
      THEN
         OPEN second_last_name_cur;

         LOOP
            EXIT WHEN second_last_name_cur%NOTFOUND;
            i := i + 1;

            FETCH second_last_name_cur
             INTO v_records_table (i);
         END LOOP;
      ELSIF p_column_name = 'FIRST_NAME'
      THEN
         OPEN first_name_cur;

         LOOP
            EXIT WHEN first_name_cur%NOTFOUND;
            i := i + 1;

            FETCH first_name_cur
             INTO v_records_table (i);
         END LOOP;
      ELSIF p_column_name = 'BIRTH_DATE'
      THEN
         OPEN birth_date_cur;

         LOOP
            EXIT WHEN birth_date_cur%NOTFOUND;
            i := i + 1;

            FETCH birth_date_cur
             INTO v_records_table (i);
         END LOOP;
      ELSIF p_column_name = 'GENDER'
      THEN
         OPEN gender_cur;

         LOOP
            EXIT WHEN gender_cur%NOTFOUND;
            i := i + 1;

            FETCH gender_cur
             INTO v_records_table (i);
         END LOOP;
      ELSIF p_column_name = 'TREATMENT'
      THEN
         OPEN treatment_cur;

         LOOP
            EXIT WHEN treatment_cur%NOTFOUND;
            i := i + 1;

            FETCH treatment_cur
             INTO v_records_table (i);
         END LOOP;
      ELSIF p_column_name = 'NATIONALITY'
      THEN
         OPEN nationality_cur;

         LOOP
            EXIT WHEN nationality_cur%NOTFOUND;
            i := i + 1;

            FETCH nationality_cur
             INTO v_records_table (i);
         END LOOP;
      ELSIF p_column_name = 'NIF_VALUE'
      THEN
         OPEN nif_value_cur;

         LOOP
            EXIT WHEN nif_value_cur%NOTFOUND;
            i := i + 1;

            FETCH nif_value_cur
             INTO v_records_table (i);
         END LOOP;
      ELSIF p_column_name = 'NIE'
      THEN
         OPEN nie_cur;

         LOOP
            EXIT WHEN nie_cur%NOTFOUND;
            i := i + 1;

            FETCH nie_cur
             INTO v_records_table (i);
         END LOOP;
      ELSIF p_column_name = 'NUMERO_S_SOCIAL'
      THEN
         OPEN numero_s_social_cur;

         LOOP
            EXIT WHEN numero_s_social_cur%NOTFOUND;
            i := i + 1;

            FETCH numero_s_social_cur
             INTO v_records_table (i);
         END LOOP;
      ELSIF p_column_name = 'IRPF'
      THEN
         OPEN irpf_cur;

         LOOP
            EXIT WHEN irpf_cur%NOTFOUND;
            i := i + 1;

            FETCH irpf_cur
             INTO v_records_table (i);
         END LOOP;
      ELSIF p_column_name = 'ID_DIRECCION'
      THEN
         OPEN id_direccion_cur;

         LOOP
            EXIT WHEN id_direccion_cur%NOTFOUND;
            i := i + 1;

            FETCH id_direccion_cur
             INTO v_records_table (i);
         END LOOP;
      ELSIF p_column_name = 'ADDRESS_LINE1'
      THEN
         OPEN address_line1_cur;

         LOOP
            EXIT WHEN address_line1_cur%NOTFOUND;
            i := i + 1;

            FETCH address_line1_cur
             INTO v_records_table (i);
         END LOOP;
      ELSIF p_column_name = 'ADDRESS_LINE2'
      THEN
         OPEN address_line2_cur;

         LOOP
            EXIT WHEN address_line2_cur%NOTFOUND;
            i := i + 1;

            FETCH address_line2_cur
             INTO v_records_table (i);
         END LOOP;
      ELSIF p_column_name = 'COUNTRY'
      THEN
         OPEN country_cur;

         LOOP
            EXIT WHEN country_cur%NOTFOUND;
            i := i + 1;

            FETCH country_cur
             INTO v_records_table (i);
         END LOOP;
      ELSIF p_column_name = 'REGION_1'
      THEN
         OPEN region_1_cur;

         LOOP
            EXIT WHEN region_1_cur%NOTFOUND;
            i := i + 1;

            FETCH region_1_cur
             INTO v_records_table (i);
         END LOOP;
      ELSIF p_column_name = 'POSTAL_CODE'
      THEN
         OPEN postal_code_cur;

         LOOP
            EXIT WHEN postal_code_cur%NOTFOUND;
            i := i + 1;

            FETCH postal_code_cur
             INTO v_records_table (i);
         END LOOP;
      ELSIF p_column_name = 'ADDRESS_LINE3'
      THEN
         OPEN address_line3_cur;

         LOOP
            EXIT WHEN address_line3_cur%NOTFOUND;
            i := i + 1;

            FETCH address_line3_cur
             INTO v_records_table (i);
         END LOOP;
--=================
      ELSIF p_column_name = 'FECHA_ANTIGUEDAD'
      THEN
         OPEN fecha_antiguedad_cur;

         LOOP
            EXIT WHEN fecha_antiguedad_cur%NOTFOUND;
            i := i + 1;

            FETCH fecha_antiguedad_cur
             INTO v_records_table (i);
         END LOOP;
      ELSIF p_column_name = 'TIPO_EMPLEADO'
      THEN
         OPEN tipo_empleado_cur;

         LOOP
            EXIT WHEN tipo_empleado_cur%NOTFOUND;
            i := i + 1;

            FETCH tipo_empleado_cur
             INTO v_records_table (i);
         END LOOP;
      ELSIF p_column_name = 'NORMAL_HOURS'
      THEN
         OPEN normal_hours_cur;

         LOOP
            EXIT WHEN normal_hours_cur%NOTFOUND;
            i := i + 1;

            FETCH normal_hours_cur
             INTO v_records_table (i);
         END LOOP;
      ELSIF p_column_name = 'WORK_CENTER'
      THEN
         OPEN work_center_cur;

         LOOP
            EXIT WHEN work_center_cur%NOTFOUND;
            i := i + 1;

            FETCH work_center_cur
             INTO v_records_table (i);
         END LOOP;
-- Ken Mod 7/18/05 added to recognize change for modelo_de_referencia (paaf.ass_attribute10)
      ELSIF p_column_name = 'MODELO_DE_REF'
      THEN
         OPEN modelo_de_cur;

         LOOP
            EXIT WHEN modelo_de_cur%NOTFOUND;
            i := i + 1;

            FETCH modelo_de_cur
             INTO v_records_table (i);
         END LOOP;
-- Ken Mod ending
      ELSIF p_column_name = 'CONVENIO'
      THEN
         OPEN convenio_cur;

         LOOP
            EXIT WHEN convenio_cur%NOTFOUND;
            i := i + 1;

            FETCH convenio_cur
             INTO v_records_table (i);
         END LOOP;
      ELSIF p_column_name = 'EPIGRAFE'
      THEN
         OPEN epigrafe_cur;

         LOOP
            EXIT WHEN epigrafe_cur%NOTFOUND;
            i := i + 1;

            FETCH epigrafe_cur
             INTO v_records_table (i);
         END LOOP;
      ELSIF p_column_name = 'GRUPO_TARIFA'
      THEN
         OPEN grupo_tarifa_cur;

         LOOP
            EXIT WHEN grupo_tarifa_cur%NOTFOUND;
            i := i + 1;

            FETCH grupo_tarifa_cur
             INTO v_records_table (i);
         END LOOP;
      ELSIF p_column_name = 'CLAVE_PERCEPCION'
      THEN
         OPEN clave_percepcion_cur;

         LOOP
            EXIT WHEN clave_percepcion_cur%NOTFOUND;
            i := i + 1;

            FETCH clave_percepcion_cur
             INTO v_records_table (i);
         END LOOP;
      ELSIF p_column_name = 'TAX_ID'
      THEN
         OPEN tax_id_cur;

         LOOP
            EXIT WHEN tax_id_cur%NOTFOUND;
            i := i + 1;

            FETCH tax_id_cur
             INTO v_records_table (i);
         END LOOP;
      ELSIF p_column_name = 'DATE_START'
      THEN
         OPEN date_start_cur;

         LOOP
            EXIT WHEN date_start_cur%NOTFOUND;
            i := i + 1;

            FETCH date_start_cur
             INTO v_records_table (i);
         END LOOP;
      ELSIF p_column_name = 'TIPO_SALARIO'
      THEN
         OPEN tipo_salario_cur;

         LOOP
            EXIT WHEN tipo_salario_cur%NOTFOUND;
            i := i + 1;

            FETCH tipo_salario_cur
             INTO v_records_table (i);
         END LOOP;
      ELSIF p_column_name = 'TIPO_DE_AJUSTE'
      THEN
         OPEN tipo_de_ajuste_cur;

         LOOP
            EXIT WHEN tipo_de_ajuste_cur%NOTFOUND;
            i := i + 1;

            FETCH tipo_de_ajuste_cur
             INTO v_records_table (i);
         END LOOP;
--==============
      ELSIF p_column_name = 'JOB_ID'
      THEN
         OPEN job_id_cur;

         LOOP
            EXIT WHEN job_id_cur%NOTFOUND;
            i := i + 1;

            FETCH job_id_cur
             INTO v_records_table (i);
         END LOOP;
      ELSIF p_column_name = 'NEW_JOB_ID'
      THEN
         OPEN new_job_id_cur;

         LOOP
            EXIT WHEN new_job_id_cur%NOTFOUND;
            i := i + 1;

            FETCH new_job_id_cur
             INTO v_records_table (i);
         END LOOP;
      ELSIF p_column_name = 'DEPARTMENTO'
      THEN
         OPEN departmento_cur;

         LOOP
            EXIT WHEN departmento_cur%NOTFOUND;
            i := i + 1;

            FETCH departmento_cur
             INTO v_records_table (i);
         END LOOP;
      ELSIF p_column_name = 'CENTRO_DE_TRABAJO'
      THEN
         OPEN centro_de_trabajo_cur;

         LOOP
            EXIT WHEN centro_de_trabajo_cur%NOTFOUND;
            i := i + 1;

            FETCH centro_de_trabajo_cur
             INTO v_records_table (i);
         END LOOP;
      ELSIF p_column_name = 'SALARY_CHANGE_DATE'
      THEN
         OPEN salary_change_date_cur;

         LOOP
            EXIT WHEN salary_change_date_cur%NOTFOUND;
            i := i + 1;

            FETCH salary_change_date_cur
             INTO v_records_table (i);
         END LOOP;
      ELSIF p_column_name = 'NIVEL_SALARIAL'
      THEN
         OPEN nivel_salarial_cur;

         LOOP
            EXIT WHEN nivel_salarial_cur%NOTFOUND;
            i := i + 1;

            FETCH nivel_salarial_cur
             INTO v_records_table (i);
         END LOOP;
      ELSIF p_column_name = 'SALARY'
      THEN
         OPEN salary_cur;

         LOOP
            EXIT WHEN salary_cur%NOTFOUND;
            i := i + 1;

            FETCH salary_cur
             INTO v_records_table (i);
         END LOOP;
      ELSIF p_column_name = 'CENTROS_DE_COSTE'
      THEN
         OPEN centros_de_coste_cur;

         LOOP
            EXIT WHEN centros_de_coste_cur%NOTFOUND;
            i := i + 1;

            FETCH centros_de_coste_cur
             INTO v_records_table (i);
         END LOOP;
---=====================
      ELSIF p_column_name = 'BANK_NAME'
      THEN
         OPEN bank_name_cur;

         LOOP
            EXIT WHEN bank_name_cur%NOTFOUND;
            i := i + 1;

            FETCH bank_name_cur
             INTO v_records_table (i);
         END LOOP;
      ELSIF p_column_name = 'BANK_BRANCH'
      THEN
         OPEN bank_branch_cur;

         LOOP
            EXIT WHEN bank_branch_cur%NOTFOUND;
            i := i + 1;

            FETCH bank_branch_cur
             INTO v_records_table (i);
         END LOOP;
      ELSIF p_column_name = 'ACCOUNT_NUMBER'
      THEN
         OPEN account_number_cur;

         LOOP
            EXIT WHEN account_number_cur%NOTFOUND;
            i := i + 1;

            FETCH account_number_cur
             INTO v_records_table (i);
         END LOOP;
      ELSIF p_column_name = 'CONTROL_ID'
      THEN
         OPEN control_id_cur;

         LOOP
            EXIT WHEN control_id_cur%NOTFOUND;
            i := i + 1;

            FETCH control_id_cur
             INTO v_records_table (i);
         END LOOP;
      ELSIF p_column_name = 'SYSTEM_PERSON_TYPE'
      THEN
         OPEN system_person_type_cur;

         LOOP
            EXIT WHEN system_person_type_cur%NOTFOUND;
            i := i + 1;

            FETCH system_person_type_cur
             INTO v_records_table (i);
         END LOOP;
      ELSIF p_column_name = 'FECHA_FIN_CONTRATO'
      THEN
         OPEN fecha_fin_contrato_cur;

         LOOP
            EXIT WHEN fecha_fin_contrato_cur%NOTFOUND;
            i := i + 1;

            FETCH fecha_fin_contrato_cur
             INTO v_records_table (i);
         END LOOP;
--  C.Chan Mod 9/23/05 to track changes of Fecha_fin_prevista field
      ELSIF p_column_name = 'FECHA_FIN_PREVISTA'
      THEN
         OPEN fecha_fin_prevista_cur;

         LOOP
            EXIT WHEN fecha_fin_prevista_cur%NOTFOUND;
            i := i + 1;

            FETCH fecha_fin_prevista_cur
             INTO v_records_table (i);
         END LOOP;
--  Added by CC on 3/14/2006 to track changes of ass_eff_date field
      ELSIF p_column_name = 'ASS_EFF_DATE'
      THEN
         OPEN ass_eff_date_cur;

         LOOP
            EXIT WHEN ass_eff_date_cur%NOTFOUND;
            i := i + 1;

            FETCH ass_eff_date_cur
             INTO v_records_table (i);
         END LOOP;
-- Ken Mod 8/12/05 to track changes of Fecha_fin_periodo field
      ELSIF p_column_name = 'FECHA_FIN_PERIODO'
      THEN
         OPEN fecha_fin_periodo_cur;

         LOOP
            EXIT WHEN fecha_fin_periodo_cur%NOTFOUND;
            i := i + 1;

            FETCH fecha_fin_periodo_cur
             INTO v_records_table (i);
         END LOOP;
-- Ken Mod 8/29/05 to track changes of Fecha_Inicio_Bonificacion and Fecha_Fin_Bonificacion fields
      ELSIF p_column_name = 'FECHA_INICIO_BONIFICACION'
      THEN
         OPEN fecha_inicio_bonificacion_cur;

         LOOP
            EXIT WHEN fecha_inicio_bonificacion_cur%NOTFOUND;
            i := i + 1;

            FETCH fecha_inicio_bonificacion_cur
             INTO v_records_table (i);
         END LOOP;
      ELSIF p_column_name = 'FECHA_FIN_BONIFICACION'
      THEN
         OPEN fecha_fin_bonificacion_cur;

         LOOP
            EXIT WHEN fecha_fin_bonificacion_cur%NOTFOUND;
            i := i + 1;

            FETCH fecha_fin_bonificacion_cur
             INTO v_records_table (i);
         END LOOP;
-- Ken Mod 8/29/05 ending...
      END IF;

      IF p_column_name IN
            ('LAST_NAME', 'SECOND_LAST_NAME', 'FIRST_NAME', 'BIRTH_DATE'
           , 'GENDER', 'TREATMENT', 'NATIONALITY', 'NIF_VALUE', 'NIE'
           , 'NUMERO_S_SOCIAL', 'IRPF', 'ID_DIRECCION', 'ADDRESS_LINE1'
           , 'ADDRESS_LINE2', 'COUNTRY', 'REGION_1', 'POSTAL_CODE'
           , 'ADDRESS_LINE3', 'FECHA_ANTIGUEDAD', 'TIPO_EMPLEADO'
           , 'NORMAL_HOURS', 'WORK_CENTER', 'MODELO_DE_REF', 'CONVENIO'
           , 'EPIGRAFE', 'GRUPO_TARIFA', 'CLAVE_PERCEPCION', 'TAX_ID'
           , 'DATE_START', 'TIPO_SALARIO', 'TIPO_DE_AJUSTE', 'JOB_ID'
           , 'NEW_JOB_ID', 'DEPARTMENTO', 'CENTRO_DE_TRABAJO'
           , 'SALARY_CHANGE_DATE', 'NIVEL_SALARIAL', 'SALARY'
           , 'CENTROS_DE_COSTE', 'BANK_NAME', 'BANK_BRANCH', 'ACCOUNT_NUMBER'
           , 'CONTROL_ID', 'SYSTEM_PERSON_TYPE', 'FECHA_FIN_CONTRATO'
           , 'FECHA_FIN_PREVISTA'
           --  C.Chan Mod 9/23/05 to track changes of Fecha_fin_prevista field
-- Ken Mod 8/12/05 to track changes of Fecha_fin_periodo field
             ,'FECHA_FIN_PERIODO'
-- Ken Mod 8/29/05 to track changes of Fecha_Inicio_Bonificacion and Fecha_Fin_Bonificacion fields
             , 'FECHA_INICIO_BONIFICACION', 'FECHA_FIN_BONIFICACION'
           , 'LEGAL_EMPLOYER'                 -- Added by C. Chan on 5/28/2009
                             )
      THEN
         l_v_index := v_records_table.FIRST;

         IF l_v_index IS NOT NULL
         THEN
            l_v_value_to_compare := v_records_table (l_v_index);
         END IF;

         l_v_record_count := v_records_table.COUNT;
      END IF;

      IF (l_v_record_count <> 0)
      THEN
         FOR i IN v_records_table.FIRST .. v_records_table.LAST
         LOOP
            IF v_records_table (i) <> l_v_value_to_compare
            THEN
               l_record_changed := 'Y';
               EXIT;                                     /* exits the loop */
            END IF;
         END LOOP;
      ELSE
         l_record_changed := 'N';
      END IF;

      RETURN (l_record_changed);
   EXCEPTION
      WHEN OTHERS
      THEN
         RETURN (l_record_changed);
   END;

---************************************************************************************
--*************************************************************************************
   PROCEDURE populate_interface_tables
   IS
      paaf_row_count                NUMBER;
      cursor_exist                  VARCHAR2 (10);
      /*
	  START R12.2 Upgrade Remediation
	  code commented by RXNETHI-ARGANO,16/05/23
	  papf_person_id                hr.per_all_people_f.person_id%TYPE;
      paaf_assignment_id            hr.per_all_assignments_f.assignment_id%TYPE;
      paaf_period_of_service_id     hr.per_all_assignments_f.period_of_service_id%TYPE;
      paaf_effective_start_date     hr.per_all_assignments_f.effective_start_date%TYPE;
      paaf_payroll_id               hr.per_all_assignments_f.payroll_id%TYPE;
      paaf_job_id                   hr.per_all_assignments_f.job_id%TYPE;
      paaf_organization_id          hr.per_all_assignments_f.organization_id%TYPE;
      paaf_soft_coding_keyflex_id   hr.per_all_assignments_f.soft_coding_keyflex_id%TYPE;
      paaf_location_id              hr.per_all_assignments_f.location_id%TYPE;
      paaf_effective_end_date       hr.per_all_assignments_f.effective_end_date%TYPE;
      pppm_external_account_id      hr.pay_personal_payment_methods_f.external_account_id%TYPE;
	  */
	  --code added by RXNETHI-ARGANO,16/05/23
	  papf_person_id                apps.per_all_people_f.person_id%TYPE;
      paaf_assignment_id            apps.per_all_assignments_f.assignment_id%TYPE;
      paaf_period_of_service_id     apps.per_all_assignments_f.period_of_service_id%TYPE;
      paaf_effective_start_date     apps.per_all_assignments_f.effective_start_date%TYPE;
      paaf_payroll_id               apps.per_all_assignments_f.payroll_id%TYPE;
      paaf_job_id                   apps.per_all_assignments_f.job_id%TYPE;
      paaf_organization_id          apps.per_all_assignments_f.organization_id%TYPE;
      paaf_soft_coding_keyflex_id   apps.per_all_assignments_f.soft_coding_keyflex_id%TYPE;
      paaf_location_id              apps.per_all_assignments_f.location_id%TYPE;
      paaf_effective_end_date       apps.per_all_assignments_f.effective_end_date%TYPE;
      pppm_external_account_id      apps.pay_personal_payment_methods_f.external_account_id%TYPE;
	  --END R12.2 Upgrade Remediation

      CURSOR c_papf_data
      IS
         SELECT   papf.employee_number oracle_employee_id
--  modified by C. Chan for WO#163242
--DECODE( SIGN(TRUNC(papf.original_date_of_hire) - TO_DATE('01-08-2005','DD-MM-YYYY')) ,  --  Modified by C.Chan on 27-DEC-2005 for TT#411517
--        -1 , papf.attribute12 , papf.employee_number)                             employee_id
                  ,NVL (papf.attribute12, papf.employee_number) employee_id
                , papf.last_name last_name
                , papf.per_information1 second_last_name
                , papf.first_name first_name
---   need to add maiden name
                  , papf.date_of_birth birth_date
                , DECODE (papf.sex, 'F', '2', 'M', '1', NULL) gender
                , DECODE (papf.title
                        , 'DR.', '04'
                        , 'MISS', '03'
                        , 'MR.', '01'
                        , 'MRS.', '02'
                        , 'MS.', '03'
                        , papf.title
                         ) treatment
                , papf.nationality nationality
                , papf.national_identifier nif_value
                , papf.marital_status marital_status
                                     -- WO#131875  added By C.Chan 09/21/2005
                , DECODE (papf.per_information2
                        , 'NIE', papf.per_information3
                        , NULL
                         ) nie
                , NULL numero_s_social, papf.attribute7 irpf
                , NULL id_direccion
--,papf.nationality                                  country
                  , papf.attribute6 ordinal_periodo
-- Added by CC on 3/8/2006
                  ,papf.original_date_of_hire
                , DECODE (papf.attribute16
                        , NULL, 0
                        , papf.attribute16
                         ) tipo_empleado
-- Ken Mod 7/18/05 pull ass_attribute9 for pago_gestiontiempo, ass_attribute10 for modelo_de_referencia field.
-- both fields are varchar2(45) in audit table
                  ,DECODE
                      (papf.attribute20
                     , '1834', '1'
                     , '1835', '2'
                     , '10325', '19'
                     , NULL
                      )       -- Added by C. Chan on Apr 23,2009 for WO#582987
                                                              legal_employer
                , papf.attribute19 fecha_de_incorporacion
                                                        -- WO#150091 added By
                , papf.attribute21 work_center, papf.attribute10 tax_id
                , papf.creation_date person_creation_date
                , papf.last_update_date person_update_date
                , papf.person_id person_id, papf.party_id party_id
                , SUBSTR (papf.attribute18, 1, 10) fecha_antiguedad
                , ppt.person_type_id person_type_id
                , ppt.system_person_type system_person_type
                , ppt.user_person_type user_person_type
                , ppt.user_person_type person_type
             /*
			 START R12.2 Upgrade Remediation
			 code commented by RXNETHI-ARGANO,16/05/23
			 FROM hr.per_all_people_f papf
                , hr.per_person_types ppt
                , hr.per_person_type_usages_f pptuf
			 */
			 --code added by RXNETHI-ARGANO,16/05/23
			 FROM apps.per_all_people_f papf
                , apps.per_person_types ppt
                , apps.per_person_type_usages_f pptuf
			 --END R12.2 Upgrade Remediaiton
			 
            WHERE papf.business_group_id = g_business_group_id
-- Ken Mod 8/17/05 it should be from pptuf then ppt
-- k AND     papf.person_type_id          = ppt.person_type_id
              AND papf.business_group_id = ppt.business_group_id
              AND papf.person_id = pptuf.person_id
              AND g_cut_off_date BETWEEN papf.effective_start_date
                                     AND papf.effective_end_date
              AND papf.effective_start_date BETWEEN pptuf.effective_start_date
                                                AND pptuf.effective_end_date
              AND pptuf.person_type_id =
                     ppt.person_type_id
          -- -- Ken Mod 8/17/05 it should be from pptuf then ppt added  by Ken
           --   AND papf.person_id IN
           --          (226451, 226514, 226575, 226662, 226765, 226786, 226836  , 226909)                            --in (226583, 230987)
--AND papf.attribute12 = '103474' --in ('118551','120366')
         ORDER BY papf.employee_number;

      CURSOR c_paaf_data
      IS
         SELECT paaf.period_of_service_id, paaf.effective_start_date
              , paaf.payroll_id, paaf.job_id, paaf.organization_id
              , paaf.soft_coding_keyflex_id, paaf.location_id
              , paaf.effective_end_date
              , paaf.effective_start_date ass_eff_date
-- Ken Mod 7/18/05 pull ass_attribute9 for pago_gestiontiempo, ass_attribute10 for modelo_de_referencia field.
-- both fields are varchar2(45) in audit table
                ,DECODE (UPPER (paaf.ass_attribute9)
                       , 'Y', 1
                       , NULL
                        ) pago_gestiontiempo
              , paaf.ass_attribute10 modelo_de_referencia
              , paaf.normal_hours normal_hours, paaf.ass_attribute7 convenio
              , DECODE (paaf.employee_category
                      , 'AAN11', '4'
                      , 'AFN3', '611'
                      , 'AN4', '99'
                      , 'AOFN12', '8'
                      , 'APN5', '611'
                      , 'ASN8', '617'
                      , 'CN8', '7'
                      , 'DN1', '12'
                      , 'GTN9', '620'
                      , 'JAN5', '609'
                      , 'JDN2', '35'
                      , 'JPN3', '603'
                      , 'OAN8', '618'
                      , 'OOPN11', '622'
                      , 'PJN6', '21'
                      , 'PSN5', '20'
                      , 'RSN5', '28'
                      , 'SAN6', '615'
                      , 'SBN7', '310'
                      , 'TAN6', '5'
                      , 'TEN10', '651'
                      , 'TMN5', '607'
                      , 'TN11', '1'
                      , 'TSAN4', '604'
                      , 'TSBN5', '610'
                      , 'TSN4', '30'
                      , paaf.employee_category
                       ) legacy_job_id
              , paaf.assignment_id assignment_id
              , paaf.creation_date assignment_creation_date
              , paaf.last_update_date assignment_update_date
              , paaf.ass_attribute6 tipo_salario
              , paaf.ass_attribute8 tipo_de_ajuste
              , DECODE (UPPER (paaf.employee_category)
                      , 'AAN11', 'NV11'
                      , 'AFN3', 'NV3'
                      , 'AN4', 'NV4'
                      , 'AOFN12', 'NV12'
                      , 'APN5', 'NV5'
                      , 'ASN8', 'NV8'
                      , 'CN8', 'NV8'
                      , 'DN1', 'NV1'
                      , 'GTN9', 'NV9'
                      , 'JAN5', 'NV5'
                      , 'JDN2', 'NV2'
                      , 'JPN3', 'NV3'
                      , 'OAN8', 'NV8'
                      , 'OOPN11', 'NV11'
                      , 'PJN6', 'NV6'
                      , 'PSN5', 'NV5'
                      , 'RSN5', 'NV5'
                      , 'SAN6', 'NV6'
                      , 'SBN7', 'NV7'
                      , 'TAN6', 'NV6'
                      , 'TEN10', 'NV10'
                      , 'TMN5', 'NV5'
                      , 'TN11', 'NV11'
                      , 'TSAN4', 'NV4'
                      , 'TSBN5', 'NV5'
                      , 'TSN4', 'NV4'
                      , paaf.employee_category
                       ) nivel_salarial
              , asttl.user_status assignment_status
-- V 1.0                                                                               paaf.employee_category  ) nivel_salarial,
           --FROM hr.per_all_assignments_f paaf  --code commented by RXNETHI-ARGANO,16/05/23
           FROM apps.per_all_assignments_f paaf  --code commented by RXNETHI-ARGANO,16/05/23
              , per_assignment_status_types_tl asttl                  -- V 1.0
          WHERE paaf.business_group_id = g_business_group_id
            AND paaf.person_id = papf_person_id
            AND paaf.assignment_status_type_id =
                                       asttl.assignment_status_type_id
                                                                      -- V 1.0
            AND asttl.LANGUAGE = 'US'                                 -- V 1.0
            AND g_cut_off_date BETWEEN paaf.effective_start_date
                                   AND paaf.effective_end_date
            AND 'EXIST' = cursor_exist
         UNION
         SELECT paaf.period_of_service_id, paaf.effective_start_date
              , paaf.payroll_id, paaf.job_id, paaf.organization_id
              , paaf.soft_coding_keyflex_id, paaf.location_id
              , paaf.effective_end_date
              , paaf.effective_start_date ass_eff_date
-- Ken Mod 7/18/05 pull ass_attribute9 for pago_gestiontiempo, ass_attribute10 for modelo_de_referencia field.
-- both fields are varchar2(45) in audit table
                ,DECODE (UPPER (paaf.ass_attribute9)
                       , 'Y', 1
                       , NULL
                        ) pago_gestiontiempo
              , paaf.ass_attribute10 modelo_de_referencia
              , paaf.normal_hours normal_hours, paaf.ass_attribute7 convenio
              , DECODE (paaf.employee_category
                      , 'AAN11', '4'
                      , 'AFN3', '611'
                      , 'AN4', '99'
                      , 'AOFN12', '8'
                      , 'APN5', '611'
                      , 'ASN8', '617'
                      , 'CN8', '7'
                      , 'DN1', '12'
                      , 'GTN9', '620'
                      , 'JAN5', '609'
                      , 'JDN2', '35'
                      , 'JPN3', '603'
                      , 'OAN8', '618'
                      , 'OOPN11', '622'
                      , 'PJN6', '21'
                      , 'PSN5', '20'
                      , 'RSN5', '28'
                      , 'SAN6', '615'
                      , 'SBN7', '310'
                      , 'TAN6', '5'
                      , 'TEN10', '651'
                      , 'TMN5', '607'
                      , 'TN11', '1'
                      , 'TSAN4', '604'
                      , 'TSBN5', '610'
                      , 'TSN4', '30'
                      , paaf.employee_category
                       ) legacy_job_id
              , paaf.assignment_id assignment_id
              , paaf.creation_date assignment_creation_date
              , paaf.last_update_date assignment_update_date
              , paaf.ass_attribute6 tipo_salario
              , paaf.ass_attribute8 tipo_de_ajuste
              , DECODE (UPPER (paaf.employee_category)
                      , 'AAN11', 'NV11'
                      , 'AFN3', 'NV3'
                      , 'AN4', 'NV4'
                      , 'AOFN12', 'NV12'
                      , 'APN5', 'NV5'
                      , 'ASN8', 'NV8'
                      , 'CN8', 'NV8'
                      , 'DN1', 'NV1'
                      , 'GTN9', 'NV9'
                      , 'JAN5', 'NV5'
                      , 'JDN2', 'NV2'
                      , 'JPN3', 'NV3'
                      , 'OAN8', 'NV8'
                      , 'OOPN11', 'NV11'
                      , 'PJN6', 'NV6'
                      , 'PSN5', 'NV5'
                      , 'RSN5', 'NV5'
                      , 'SAN6', 'NV6'
                      , 'SBN7', 'NV7'
                      , 'TAN6', 'NV6'
                      , 'TEN10', 'NV10'
                      , 'TMN5', 'NV5'
                      , 'TN11', 'NV11'
                      , 'TSAN4', 'NV4'
                      , 'TSBN5', 'NV5'
                      , 'TSN4', 'NV4'
                      , paaf.employee_category
                       ) nivel_salarial
              , asttl.user_status assignment_status                   -- V 1.0
           --FROM hr.per_all_assignments_f paaf  --code commented by RXNETHI-ARGANO,16/05/23
           FROM apps.per_all_assignments_f paaf    --code commented by RXNETHI-ARGANO,16/05/23
              , per_assignment_status_types_tl asttl                  -- V 1.0
          WHERE paaf.business_group_id = g_business_group_id
            AND paaf.person_id = papf_person_id
            AND paaf.assignment_status_type_id =
                                       asttl.assignment_status_type_id
                                                                      -- V 1.0
            AND asttl.LANGUAGE = 'US'                                 -- V 1.0
            AND paaf.effective_start_date =
                   (SELECT MAX (effective_start_date)
                      FROM per_assignments_f
                     WHERE assignment_id = paaf.assignment_id
                       AND person_id = paaf.person_id
                       AND effective_start_date <= g_cut_off_date)
            AND 'NOT EXIST' = cursor_exist;

/*CURSOR c_emp_pps_data IS
SELECT pps.period_of_service_id                                   period_of_service_id
,pps.date_start                                                   date_start
,pps.actual_termination_date                                      actual_termination_date
,pps.notified_termination_date                                    notified_termination_date  -- WO#150091  added By C.Chan 12/21/2005
,pps.leaving_reason                                               leaving_reason
 FROM  hr.per_periods_of_service  pps
WHERE   pps.person_id            = papf_person_id
AND     pps.period_of_service_id = paaf_period_of_service_id;
*/
      CURSOR c_pcf_data
      IS
         SELECT pcf.start_reason motivo_alta
              , pcf.REFERENCE id_contrato_interno
              , pcf.ctr_information4 fecha_fin_prevista
              , pcf.ctr_information4 fecha_fin_periodo
              , pcf.ctr_information7 original_contract_end_date
              , pcf.attribute1 fecha_inicio_bonificacion
              , pcf.attribute2 fecha_fin_bonificacion
              , DECODE (TO_CHAR (pcf.effective_end_date, 'yyyy')
                      , '4712', NULL
                      , pcf.effective_end_date
                       ) fecha_fin_contrato
              , pcf.effective_start_date fecha_inicio_cont_específico
              , hr_contract_api.get_active_start_date
                       (pcf.contract_id
                      , TO_DATE (g_cut_off_date)
                      , pcf.status
                       ) original_contract_start_date
              , hr_contract_api.get_active_end_date
                           (pcf.contract_id
                          , TO_DATE (g_cut_off_date)
                          , pcf.status
                           ) contract_active_end_date
              , hr_contract_api.get_pps_start_date
                   (pcf.person_id
                  , hr_contract_api.get_active_start_date
                                                     (pcf.contract_id
                                                    , TO_DATE (g_cut_off_date)
                                                    , pcf.status
                                                     )
                   ) contract_pps_start_date
              , hr_contract_api.get_pps_end_date
                   (pcf.person_id
                  , hr_contract_api.get_active_start_date
                                                     (pcf.contract_id
                                                    , TO_DATE (g_cut_off_date)
                                                    , pcf.status
                                                     )
                   ) contract_pps_end_date
              , pcf.last_update_date contract_update_date
--FROM per_contracts_f pcf /* commented out for V 1.0 */
         FROM   per_contracts pcf                      /* V 1.0 for bug fix */
          WHERE pcf.person_id = papf_person_id
            AND (   status != 'T-TERMINATE'
                 OR pcf.start_reason != 4
                )                                        /* 4 -> Excedencia */
--AND g_cut_off_date BETWEEN pcf.EFFECTIVE_START_DATE AND pcf.EFFECTIVE_END_DATE;  /* commented out for V 1.0 */
            AND g_cut_off_date BETWEEN active_start_date
                                   AND NVL
                                         (active_end_date, '12-DEC-4712')
                                                       /* V 1.0 for bug fix */
         UNION
       /* Added this to pick up contract for employee who has Excedendencia */
         SELECT pcf.start_reason motivo_alta
              , pcf.REFERENCE id_contrato_interno
              , pcf.ctr_information4 fecha_fin_prevista
              , pcf.ctr_information4 fecha_fin_periodo
              , pcf.ctr_information7 original_contract_end_date
              , pcf.attribute1 fecha_inicio_bonificacion
              , pcf.attribute2 fecha_fin_bonificacion
              , DECODE (TO_CHAR (pcf.effective_end_date, 'yyyy')
                      , '4712', NULL
                      , pcf.effective_end_date
                       ) fecha_fin_contrato
              , pcf.effective_start_date fecha_inicio_cont_específico
              , hr_contract_api.get_active_start_date
                       (pcf.contract_id
                      , TO_DATE (g_cut_off_date)
                      , pcf.status
                       ) original_contract_start_date
              , hr_contract_api.get_active_end_date
                           (pcf.contract_id
                          , TO_DATE (g_cut_off_date)
                          , pcf.status
                           ) contract_active_end_date
              , pcf.effective_start_date contract_pps_start_date
              , pcf.effective_end_date contract_pps_end_date
              , pcf.last_update_date contract_update_date
--FROM per_contracts_f pcf /* commented out for V 1.0 */
         FROM   per_contracts pcf                      /* V 1.0 for bug fix */
          WHERE pcf.person_id = papf_person_id
            AND status = 'T-TERMINATE'
            AND pcf.start_reason = 4                     /* 4 -> Excedencia */
            AND g_cut_off_date BETWEEN pcf.effective_start_date
                                   AND pcf.effective_end_date
            and pcf.effective_start_date = (select max(pcf2.effective_start_date)
                                            FROM   per_contracts pcf2
                                            where pcf2.person_id = pcf.person_id);

      CURSOR c_ppayf_data
      IS
         SELECT ppayf.payroll_id payroll_id, ppayf.payroll_name payroll_name
              , ppayf.cost_allocation_keyflex_id
           --FROM hr.pay_all_payrolls_f ppayf --code commented by RXNETHI-ARGANO,16/05/23
		   FROM apps.pay_all_payrolls_f ppayf --code added by RXNETHI-ARGANO,16/05/23
          WHERE ppayf.payroll_id = paaf_payroll_id
            AND g_cut_off_date BETWEEN ppayf.effective_start_date
                                   AND ppayf.effective_end_date;

/*CURSOR c_pppm_data IS
SELECT pppm.external_account_id pppm_external_account_id
,DECODE(pppm.ORG_PAYMENT_METHOD_ID,175,2,174,3,176,4,171,2,172,3,173,4,NULL)  tipo_de_pago
,pppm.effective_start_date                                        pppm_effective_date
FROM pay_personal_payment_methods_f  pppm
WHERE pppm.business_group_id = 1804
AND pppm.assignment_id = papf_assignment_id
AND g_cut_off_date BETWEEN pppm.effective_start_date AND pppm.effective_end_date;
CURSOR c_pppm_data_latest IS
SELECT pppm.external_account_id pppm_external_account_id
,DECODE(pppm.ORG_PAYMENT_METHOD_ID,175,2,174,3,176,4,171,2,172,3,173,4,NULL)  tipo_de_pago
,pppm.effective_start_date                                        pppm_effective_date
FROM pay_personal_payment_methods_f  pppm
WHERE pppm.business_group_id = 1804
AND pppm.assignment_id = paaf_assignment_id
AND TRUNC(pppm.effective_start_date) = (SELECT    MAX(effective_start_date)
                                             FROM     pay_personal_payment_methods_f
                                           WHERE    assignment_id = paaf_assignment_id
                                            AND      effective_start_date <= g_cut_off_date);*/
/*CURSOR c_pea_data IS
SELECT pea.segment1              bank_name
,pea.segment1|| pea.segment2     bank_branch
,pea.segment3                 account_number
,pea.segment5                 control_id
FROM hr.pay_external_accounts                  pea
WHERE pea.external_account_id = pppm_external_account_id;   */
/*CURSOR c_hsck_data IS
SELECT hsck.SEGMENT5                                         grupo_tarifa
,DECODE(hsck.SEGMENT2,1969,30,1821,1,1826,15,1827,16,1841,17,1842,18
                     ,1828,19,1822,2,1843,20,1829,21,1830,27,1831,28
                     ,1832,29,1844,3,1833,31,1823,4,1824,5,1825,7,NULL)  centro_de_trabajo
FROM hr.HR_SOFT_CODING_KEYFLEX  hsck
WHERE hsck.SOFT_CODING_KEYFLEX_ID = paaf_SOFT_CODING_KEYFLEX_ID;
*/
-- CCCC
      CURSOR c_pcak_data
      IS
         SELECT NVL (pcaf.proportion, 0) * 100 costing_pct
              , DECODE (pcak.segment3
                      , '005', '1'
                      , '020', '2'
                      , '085', '3'
                      , '040', '4'
                      , '055', '5'
                      , '060', '6'
                      , '015', '7'
                      , '090', '8'
                      , '045', '10'
                      , '056', '11'
                      , pcak.segment3
                       ) departmento
              ,    DECODE (pcak1.segment1
                         , NULL, hla.attribute2
                         , pcak1.segment1
                          )
                || pcak1.segment2
                || DECODE (pcak1.segment3
                         , NULL, pcak.segment3
                         , pcak1.segment3
                          ) centros_de_coste
              , pcaf.effective_start_date costsegment_dt
              , pcaf.last_update_date pcaf_update_date
--By C. Chan for WO#293166 on Aug 08,2007
--
                ,DECODE
                    (hla.attribute2
                   , '04210', 1
                   , '04200', 1
                   , '04216', 4
                   , '04225', 5
                   , '04230', 7
                   , '04257', 29
                   , '04260', 19
                   , '04262', 35
                   , '04235', 28
                   , '04290', 21
                   , '04211', 36
                            -- Added by C. Chan on June 13, 2008 for TT#965056
--,'04226',37 -- Added by C. Chan on March 12, 2009 for TT#570394
-- Added by C. Chan on June 10, 2009 for WO#602234
                 ,   '04226', DECODE
                        ((SELECT SUBSTR (hsck.concatenated_segments
                                       , 1
                                       ,   INSTR (hsck.concatenated_segments
                                                , '.'
                                                , 1
                                                , 1
                                                 )
                                         - 1
                                        )
                            --FROM hr.hr_soft_coding_keyflex hsck --code commented by RXNETHI-ARGANO,16/05/23
                            FROM apps.hr_soft_coding_keyflex hsck --code added by RXNETHI-ARGANO,16/05/23
                           WHERE hsck.soft_coding_keyflex_id =
                                                   paaf_soft_coding_keyflex_id)
                       , 'ESP-@Home Madrid', 38
                       , 'ESP-@Home Oviedo', 39
                            -- Added by C. Chan on Aug 11, 2009 for WO# 621742
                       , 'ESP-@Home Valencia', 37
                        )
                    ) centro_de_trabajo
           FROM pay_cost_allocation_keyflex pcak
              , hr_all_organization_units haou
              , hr_locations_all hla
              , pay_cost_allocations_f pcaf
              , pay_cost_allocation_keyflex pcak1
          WHERE hla.location_id = paaf_location_id
            AND pcaf.assignment_id = paaf_assignment_id
            AND pcak.cost_allocation_keyflex_id =
                                               haou.cost_allocation_keyflex_id
            AND haou.organization_id =
                     paaf_organization_id
                                         -- Modified by C. Chan for  TT#615375
            AND pcak1.cost_allocation_keyflex_id =
                                               pcaf.cost_allocation_keyflex_id
            AND g_cut_off_date BETWEEN pcaf.effective_start_date
                                   AND pcaf.effective_end_date;

      CURSOR c_pcak_data_latest
      IS
         SELECT DECODE (pcak.segment3
                      , '005', '1'
                      , '020', '2'
                      , '085', '3'
                      , '040', '4'
                      , '055', '5'
                      , '060', '6'
                      , '015', '7'
                      , '090', '8'
                      , '045', '10'
                      , '056', '11'
                      , pcak.segment3
                       ) departmento
              ,    DECODE (pcak1.segment1
                         , NULL, hla.attribute2
                         , pcak1.segment1
                          )
                || pcak1.segment2
                || DECODE (pcak1.segment3
                         , NULL, pcak.segment3
                         , pcak1.segment3
                          ) centros_de_coste
              , pcaf.effective_start_date costsegment_dt
--By C. Chan for WO#293166 on Aug 08,2007
--
                ,DECODE
                    (hla.attribute2
                   , '04210', 1
                   , '04200', 1
                   , '04216', 4
                   , '04225', 5
                   , '04230', 7
                   , '04257', 29
                   , '04260', 19
                   , '04262', 35
                   , '04235', 28
                   , '04290', 21
                   , '04211', 36
                            -- Added by C. Chan on June 13, 2008 for TT#965056
--,'04226',37 -- Added by C. Chan on March 12, 2009 for TT#570394
-- Added by C. Chan on June 10, 2009 for WO#602234
                 ,   '04226', DECODE
                        ((SELECT SUBSTR (hsck.concatenated_segments
                                       , 1
                                       ,   INSTR (hsck.concatenated_segments
                                                , '.'
                                                , 1
                                                , 1
                                                 )
                                         - 1
                                        )
                            --FROM hr.hr_soft_coding_keyflex hsck  --code commented by RXNETHI-ARGANO,16/05/23
                            FROM apps.hr_soft_coding_keyflex hsck  --code added by RXNETHI-ARGANO,16/05/23
                           WHERE hsck.soft_coding_keyflex_id =
                                                   paaf_soft_coding_keyflex_id)
                       , 'ESP-@Home Madrid', 38
                       , 'ESP-@Home Oviedo', 39
                            -- Added by C. Chan on Aug 11, 2009 for WO# 621742
                       , 'ESP-@Home Valencia', 37
                        )
                    ) centro_de_trabajo
           FROM pay_cost_allocation_keyflex pcak
              , hr_all_organization_units haou
              , hr_locations_all hla
              , pay_cost_allocations_f pcaf
              , pay_cost_allocation_keyflex pcak1
          WHERE hla.location_id = paaf_location_id
            AND pcaf.assignment_id = paaf_assignment_id
            AND pcak.cost_allocation_keyflex_id =
                                               haou.cost_allocation_keyflex_id
            AND haou.organization_id =
                     paaf_organization_id
                                         -- Modified by C. Chan for  TT#615375
            AND pcak1.cost_allocation_keyflex_id =
                                               pcaf.cost_allocation_keyflex_id
            AND pcaf.effective_start_date =
                   (SELECT MAX (effective_start_date)
                      FROM pay_cost_allocations_f
                     WHERE assignment_id = paaf_assignment_id
                       AND effective_start_date <= g_cut_off_date);

-- Ken Mod starting.. 7/21/05 to capture pps data for each day, and used to calcualte term/rehire
      CURSOR c_term_his_emp_data (
         cv_person_id                   NUMBER
       , cv_papf_effective_start_date   DATE
       , cv_papf_effective_end_date     DATE
       , cv_paaf_effective_start_date   DATE
       , cv_paaf_effective_end_date     DATE
       , cv_date_start                  DATE
       , cv_paaf_assignment_id          NUMBER
      )
      IS
         SELECT   papf.employee_number oracle_employee_id
--  modified by C. Chan for WO#163242
--DECODE( SIGN(TRUNC(papf.original_date_of_hire) - TO_DATE('01-08-2005','DD-MM-YYYY')) , -- 12/23/2005 modified by C. Chan 01-AUG-2005 to 01-08-2005 may resolve the language issue
--        -1 , papf.attribute12 , papf.employee_number)                                            employee_id
                  ,NVL (papf.attribute12, papf.employee_number) employee_id
                , papf.last_name last_name
                , papf.per_information1 second_last_name
                , papf.first_name first_name
---   need to add maiden name
                  , papf.date_of_birth birth_date
                , DECODE (papf.sex, 'F', '2', 'M', '1', NULL) gender
                , DECODE (papf.title
                        , 'DR.', '04'
                        , 'MISS', '03'
                        , 'MR.', '01'
                        , 'MRS.', '02'
                        , 'MS.', '03'
                        , papf.title
                         ) treatment
                , papf.nationality nationality
                , papf.national_identifier nif_value
                , papf.marital_status marital_status
                                      -- WO#131875  added By C.Chan 09/21/2005
                , DECODE (papf.per_information2
                        , 'NIE', papf.per_information3
                        , NULL
                         ) nie
                , NULL numero_s_social, papf.attribute7 irpf
                , NULL id_direccion, addr.address_line1 address_line1
                , addr.address_line2 address_line2, addr.country country
--,papf.nationality                               country
                  ,addr.town_or_city region_1
-- ,addr.region_2                                                                                -- region_1
                  , addr.postal_code postal_code
                , DECODE (addr.address_line3
                        , NULL, '0'
                        , addr.address_line3
                         ) address_line3
                , papf.attribute6 ordinal_periodo
                , paaf.effective_start_date ass_eff_date
                , pcf.start_reason motivo_alta
                , SUBSTR (papf.attribute18, 1, 10) fecha_antiguedad
                , NULL fecha_extra
                , DECODE (papf.attribute16
                        , NULL, 0
                        , papf.attribute16
                         ) tipo_empleado
-- Ken Mod 7/18/05 pull ass_attribute9 for pago_gestiontiempo, ass_attribute10 for modelo_de_referencia field.
-- both fields are varchar2(45) in audit table
                  ,DECODE (UPPER (paaf.ass_attribute9)
                         , 'Y', 1
                         , NULL
                          ) pago_gestiontiempo
                , paaf.ass_attribute10 modelo_de_referencia
                , DECODE
                     (papf.attribute20
                    , '1834', '1'
                    , '1835', '2'
                    , '10325', '19'
                    , NULL
                     )        -- Added by C. Chan on Apr 23,2009 for WO#585359
                                                               legal_employer
                , NULL id_contrato_interno, NULL fecha_fin_prevista
-- Ken Mod 8/10/05 to pull Fecha_fin_periodo field from ctr_information4.per_contracts_f
-- and show it field #32 in NAEN section and field #14 in MAP section
-- ,NULL                                                                                       Fecha_fin_periodo
                  ,pcf.ctr_information4 fecha_fin_periodo
-- Ken Mod 8/29/05 to capture additional fields
                  ,pcf.attribute1 fecha_inicio_bonificacion
                , pcf.attribute2 fecha_fin_bonificacion
-- Ken Mod 8/29/05 ending..
                  ,DECODE
                        (TO_CHAR (pcf.effective_end_date, 'yyyy')
                       , '4712', NULL
                       , pcf.effective_end_date
                        ) fecha_fin_contrato
                , NULL clausulas_adicionales, NULL condicion_desempleado
                , NULL relacion_laboral_especial, NULL causa_sustitucion
                , NULL mujer_subrepresentda, NULL incapacitado_readmitido
                , NULL primer_trabajador_autonomo, NULL exclusion_social
                , pcf.effective_start_date fecha_inicio_cont_específico
                , NULL fic_especifico, NULL numero_ss_sustituido
                , NULL renta_active_insercion, NULL mujer_mater_24_meses
                , NULL mantiene_contrato_legal, NULL contrato_relevo
                , NULL mujer_reincorporada, NULL excluido_fichero_afi
                , paaf.normal_hours normal_hours
                , papf.attribute19 fecha_de_incorporacion
                , papf.attribute21 work_center, paaf.ass_attribute7 convenio
                , NULL epigrafe, hsck.segment5 grupo_tarifa
                , NULL clave_percepcion, papf.attribute10 tax_id
                , paaf.ass_attribute6 tipo_salario
                , paaf.ass_attribute8 tipo_de_ajuste
                , DECODE (paaf.employee_category
                        , 'AAN11', '4'
                        , 'AFN3', '611'
                        , 'AN4', '99'
                        , 'AOFN12', '8'
                        , 'APN5', '611'
                        , 'ASN8', '617'
                        , 'CN8', '7'
                        , 'DN1', '12'
                        , 'GTN9', '620'
                        , 'JAN5', '609'
                        , 'JDN2', '35'
                        , 'JPN3', '603'
                        , 'OAN8', '618'
                        , 'OOPN11', '622'
                        , 'PJN6', '21'
                        , 'PSN5', '20'
                        , 'RSN5', '28'
                        , 'SAN6', '615'
                        , 'SBN7', '310'
                        , 'TAN6', '5'
                        , 'TEN10', '651'
                        , 'TMN5', '607'
                        , 'TN11', '1'
                        , 'TSAN4', '604'
                        , 'TSBN5', '610'
                        , 'TSN4', '30'
                        , paaf.employee_category
                         ) job_id
                , SUBSTR (pj.NAME, 1, INSTR (pj.NAME, '.') - 1) new_job_id
                -- ,TO_NUMBER(pcak.segment3)                             departmento
                 /* ,DECODE(pcak.segment3 ,'005','CAMPANA',
                                           '020','DIRECCION',
                         '085','MARKETING',
                         '040','RRHH',
                         '055','SISTEMAS',
                         '060','SERVICIOS GENERALES',
                         '015','FINANCIERO',
                         '090','LEGAL',
                         '045','GESTION CLIENTES',
                         '056','OPERACIONES' , pcak.segment3 )  departmento*/
                  ,DECODE (pcak.segment3
                         , '005', '1'
                         , '020', '2'
                         , '085', '3'
                         , '040', '4'
                         , '055', '5'
                         , '060', '6'
                         , '015', '7'
                         , '090', '8'
                         , '045', '10'
                         , '056', '11'
                         , pcak.segment3
                          ) departmento
 -- ,haou.NAME                centro_de_trabajo
/* Commented out By C. Chan for WO#293166 on Aug 08,2007
,DECODE(hsck.SEGMENT2,2230,35,1969,30,1821,1,1826,15,1827,16,1841,17,1842,18,1828,19,1822,2,1843,20,1829,21,1830,27,1831,28,
                      1832,29,1844,3,1833,31,1823,4,1824,5,1825,7,NULL)       centro_de_trabajo
*/
--Added By C. Chan for WO#293166 on Aug 08,2007
--
                  ,DECODE
                      (hla.attribute2
                     , '04210', 1
                     , '04200', 1
                     , '04216', 4
                     , '04225', 5
                     , '04230', 7
                     , '04257', 29
                     , '04260', 19
                     , '04262', 35
                     , '04235', 28
                     , '04290', 21
                     , '04211', 36
                            -- Added by C. Chan on June 13, 2008 for TT#965056
--,'04226',37 -- Added by C. Chan on March 12, 2009 for TT#570394
-- Added by C. Chan on June 10, 2009 for WO#602234
                   ,   '04226', DECODE
                          ((SELECT SUBSTR (hsck.concatenated_segments
                                         , 1
                                         ,   INSTR
                                                  (hsck.concatenated_segments
                                                 , '.'
                                                 , 1
                                                 , 1
                                                  )
                                           - 1
                                          )
                              --FROM hr.hr_soft_coding_keyflex hsck   --code commented by RXNETHI-ARGANO,16/05/23
                              FROM apps.hr_soft_coding_keyflex hsck   --code added by RXNETHI-ARGANO,16/05/23
                             WHERE hsck.soft_coding_keyflex_id =
                                                   paaf_soft_coding_keyflex_id)
                         , 'ESP-@Home Madrid', 38
                         , 'ESP-@Home Oviedo', 39
                            -- Added by C. Chan on Aug 11, 2009 for WO# 621742
                         , 'ESP-@Home Valencia', 37
                          )
                      ) centro_de_trabajo
                , DECODE (UPPER (paaf.employee_category)
                        , 'AAN11', 'NV11'
                        , 'AFN3', 'NV3'
                        , 'AN4', 'NV4'
                        , 'AOFN12', 'NV12'
                        , 'APN5', 'NV5'
                        , 'ASN8', 'NV8'
                        , 'CN8', 'NV8'
                        , 'DN1', 'NV1'
                        , 'GTN9', 'NV9'
                        , 'JAN5', 'NV5'
                        , 'JDN2', 'NV2'
                        , 'JPN3', 'NV3'
                        , 'OAN8', 'NV8'
                        , 'OOPN11', 'NV11'
                        , 'PJN6', 'NV6'
                        , 'PSN5', 'NV5'
                        , 'RSN5', 'NV5'
                        , 'SAN6', 'NV6'
                        , 'SBN7', 'NV7'
                        , 'TAN6', 'NV6'
                        , 'TEN10', 'NV10'
                        , 'TMN5', 'NV5'
                        , 'TN11', 'NV11'
                        , 'TSAN4', 'NV4'
                        , 'TSBN5', 'NV5'
                        , 'TSN4', 'NV4'
                        , paaf.employee_category
                         ) nivel_salarial
--,REPLACE(paaf.employee_category,'NV')                    nivel_salarial
                  ,    DECODE (pcak1.segment1
                             , NULL, hla.attribute2
                             , pcak1.segment1
                              )
                    || pcak1.segment2
                    || DECODE (pcak1.segment3
                             , NULL, pcak.segment3
                             , pcak1.segment3
                              ) centros_de_coste
                , LTRIM (TO_CHAR (ppp.proposed_salary_n, '999999999999.99')
                        ) salary
                , pea.segment1 bank_name
                , pea.segment1 || pea.segment2 bank_branch
                , pea.segment3 account_number, pea.segment5 control_id
                , DECODE (pppm.org_payment_method_id
                        , 175, 2
                        , 174, 3
                        , 176, 4
                        , 171, 2
                        , 172, 3
                        , 173, 4
                        , NULL
                         ) tipo_de_pago
                , '1' banco_emisor
-- ,'0182'                              banco_emisor
--,addr.region_2                                                                    region_2
-- ,addr.town_or_city                                                             town_or_city
                  ,addr.telephone_number_1 telephone1
                                       -- WO#144030 added By C.Chan 12/21/2005
                , addr.telephone_number_2 telephone2
                                       -- WO#144030 added By C.Chan 12/21/2005
                , ppt.user_person_type person_type, pps.date_start date_start
                , ppp.change_date salary_change_date
--      Other required Fields for the detecting the change
                  ,papf.creation_date person_creation_date
                , papf.last_update_date person_update_date
                , paaf.assignment_id assignment_id
                , paaf.creation_date assignment_creation_date
                , paaf.last_update_date assignment_update_date
                , ppayf.payroll_id payroll_id
                , ppayf.payroll_name payroll_name, papf.person_id person_id
                , papf.party_id party_id, ppt.person_type_id person_type_id
                , ppt.system_person_type system_person_type
                , ppt.user_person_type user_person_type
                , pps.period_of_service_id period_of_service_id
                , pps.actual_termination_date actual_termination_date
                , pps.notified_termination_date notified_termination_date
                                      -- WO#150091  added By C.Chan 12/21/2005
                , pps.leaving_reason leaving_reason
                , pppm.effective_start_date pppm_effective_date
                , addr.date_from address_date_start
-- ,SYSDATE                          CostSegment_dt
-- ,pcak.LAST_UPDATE_DATE                                         CostSegment_dt
-- Ken Mod 7/18/05 Per Andy CostSegment_dt is from pcaf.EFFECTIVE_START_DATE
                  ,pcaf.effective_start_date costsegment_dt
             /*
			 START R12.2 Upgrade Remediation
			 code commented by RXNETHI-ARGANO,16/05/23
			 FROM hr.per_all_people_f papf
                , hr.per_all_assignments_f paaf
                , hr.per_addresses addr
                , hr.per_person_types ppt
                , hr.per_periods_of_service pps
                , per_pay_proposals ppp
                , hr.per_person_type_usages_f pptuf
                , hr.pay_all_payrolls_f ppayf
                , hr.per_jobs pj
			 */
			 --code added by RXNETHI-ARGANO,16/05/23
			 FROM apps.per_all_people_f papf
                , apps.per_all_assignments_f paaf
                , apps.per_addresses addr
                , apps.per_person_types ppt
                , apps.per_periods_of_service pps
                , per_pay_proposals ppp
                , apps.per_person_type_usages_f pptuf
                , apps.pay_all_payrolls_f ppayf
                , apps.per_jobs pj
			 --END R12.2 Upgrade Remediation
                , pay_cost_allocation_keyflex pcak
                , hr_all_organization_units haou
                , pay_personal_payment_methods_f pppm
                , pay_external_accounts pea
                , hr_soft_coding_keyflex hsck
                , hr_locations_all hla
                , pay_cost_allocations_f pcaf
                , pay_cost_allocation_keyflex pcak1
                , per_contracts_f pcf
-- KENXXX
         WHERE    papf.business_group_id = g_business_group_id
              AND papf.person_id =
                              cv_person_id
                                          -- difference from c_emp_data cursor
              AND papf.person_id = paaf.person_id
-- AND     g_cut_off_date BETWEEN papf.effective_start_date AND papf.effective_end_date
--  try to find papf row for EX-EMP
              AND TRUNC (cv_papf_effective_end_date + 1)
                     BETWEEN TRUNC (papf.effective_start_date)
                         AND TRUNC
                               (papf.effective_end_date)
                                          -- difference from c_emp_data cursor
---k AND     trunc(papf.effective_start_date)    = trunc(cv_papf_effective_start_date)  -- difference from c_emp_data cursor
---k AND     trunc(papf.effective_end_date)    = trunc(cv_papf_effective_end_date)      -- difference from c_emp_data cursor
              AND papf.business_group_id = paaf.business_group_id
-- AND     paaf.effective_start_date    = (SELECT    MAX(effective_start_date)
--                                           FROM     per_assignments_f
--                            WHERE    assignment_id = paaf.assignment_id
--                               AND      effective_start_date <= g_cut_off_date)
--  for term and final processed on or before today (v_extract_date), there is no active asginment record, so using previously
--  active assignment rows. and all same way for the rest of assignment related conditions.
              AND TRUNC (paaf.effective_start_date) =
                     TRUNC
                        (cv_paaf_effective_start_date)
                                          -- difference from c_emp_data cursor
              AND TRUNC (paaf.effective_end_date) =
                     TRUNC
                        (cv_paaf_effective_end_date)
                                          -- difference from c_emp_data cursor
              AND paaf.assignment_id =
                     cv_paaf_assignment_id
                                          -- difference from c_emp_data cursor
              AND papf.person_id = addr.person_id(+)
              AND g_cut_off_date BETWEEN addr.date_from(+) AND NVL (addr.date_to(+)
                                                                  , SYSDATE
                                                                   )
              AND UPPER (addr.primary_flag(+)) = 'Y'
-- Ken Mod 8/17/05 it should be from pptuf then ppt
-- k AND     papf.person_type_id          = ppt.person_type_id
              AND papf.business_group_id = ppt.business_group_id
              AND papf.person_id = pps.person_id
--AND     pps.date_start               = (SELECT MAX(date_start)
--                                          FROM   per_periods_of_service
--               WHERE  person_id = pps.person_id
--                                          AND    date_start <=  TRUNC(g_cut_off_date))
              AND TRUNC (pps.date_start) =
                     TRUNC (cv_date_start)
                                          -- difference from c_emp_data cursor
              AND paaf.assignment_id = ppp.assignment_id(+)
              AND NVL (ppp.change_date, TO_DATE ('2000-01-01', 'yyyy-mm-dd')) =
                     (SELECT NVL
                                (MAX (change_date)
                               , TO_DATE ('2000-01-01', 'yyyy-mm-dd')
                                )
                           --  Modified by C.Chan on 27-DEC-2005 for TT#411517
                        FROM per_pay_proposals ppp1
                       WHERE ppp1.assignment_id = ppp.assignment_id
                         AND ppp1.approved = 'Y'
                         AND ppp1.change_date <=
                                            TRUNC (cv_papf_effective_end_date))
                                                 -- used be g_cut_off_date ???
-- Ken Mod 8/17/05 it should be from pptuf then ppt
-- k AND     papf.person_type_id          = pptuf.person_type_id
              AND papf.person_id = pptuf.person_id
-- AND     g_cut_off_date BETWEEN pptuf.effective_start_date AND pptuf.effective_end_date
--  try to find papf row for EX-EMP
              AND TRUNC (cv_papf_effective_end_date + 1)
                     BETWEEN TRUNC (pptuf.effective_start_date)
                         AND TRUNC
                               (pptuf.effective_end_date)
                                          -- difference from c_emp_data cursor
---k AND     trunc(pptuf.effective_start_date) = trunc(cv_papf_effective_start_date)    -- difference from c_emp_data cursor
---k AND     trunc(pptuf.effective_end_date) = trunc(cv_papf_effective_end_date)        -- difference from c_emp_data cursor
              AND pptuf.person_type_id =
                     ppt.person_type_id
          -- -- Ken Mod 8/17/05 it should be from pptuf then ppt added  by Ken
              AND paaf.payroll_id = ppayf.payroll_id(+)
-- Ken Mod 8/17/05 the following commented line never work, changed it not to drop any rows..
-- k AND     g_cut_off_date BETWEEN ppayf.effective_start_date(+) AND ppayf.effective_end_date(+)   -- ok with g_cut_off_date
              AND (   (g_cut_off_date BETWEEN ppayf.effective_start_date
                                          AND ppayf.effective_end_date
                      )                                          -- mod by Ken
                   OR (ppayf.effective_start_date IS NULL)
                  )
              AND paaf.job_id = pj.job_id(+)
-- Ken Mod 8/17/05 changed it not to drop any rows..
-- k AND     haou.organization_id = paaf.organization_id
              AND haou.organization_id(+) = paaf.organization_id -- mod by Ken
-- Ken Mod 8/17/05 changed it not to drop any rows..
-- k AND     haou.COST_ALLOCATION_KEYFLEX_ID = pcak.COST_ALLOCATION_KEYFLEX_ID
              AND haou.cost_allocation_keyflex_id = pcak.cost_allocation_keyflex_id(+)
                                                                 -- mod by Ken
              AND pppm.assignment_id(+) = paaf.assignment_id
--AND    pppm.business_group_id  = papf.business_group_id
-- AND     g_cut_off_date BETWEEN pppm.effective_start_date (+) AND pppm.effective_end_date (+)
--      assignment related conditions.
--k AND     trunc(cv_papf_effective_end_date) = pppm.effective_end_date (+)            -- difference from c_emp_data cursor
-- for the case term and final processed on or before today, but final process date is later than actual term date need to use
-- cv_paaf_effective_end_date for pppm table
              AND (   TRUNC (cv_papf_effective_end_date) =
                         pppm.effective_end_date
                                          -- difference from c_emp_data cursor
                   OR TRUNC (cv_paaf_effective_end_date) =
                         pppm.effective_end_date
                                    -- outer join not allowed, so took out (+)
                   OR pppm.effective_end_date IS NULL
                  )               -- for now row from paaf and pppm outer join
              AND pppm.external_account_id = pea.external_account_id(+)
-- Ken Mod 8/17/05 changed it not to drop any rows..
-- k AND     paaf.SOFT_CODING_KEYFLEX_ID = hsck.SOFT_CODING_KEYFLEX_ID
              AND paaf.soft_coding_keyflex_id = hsck.soft_coding_keyflex_id(+)
                                                                 -- mod by Ken
-- Ken Mod 8/17/05 changed it not to drop any rows..
-- k AND     paaf.location_id = hla.location_id
              AND paaf.location_id = hla.location_id(+)          -- mod by Ken
-- Ken Mod 8/17/05 changed it not to drop any rows..
-- k AND     paaf.assignment_id = pcaf.assignment_id
              AND paaf.assignment_id = pcaf.assignment_id(+)     -- mod by Ken
-- AND     g_cut_off_date  BETWEEN pcaf.effective_start_date AND pcaf.effective_end_date
--      assignment related conditions.
--k AND     trunc(pcaf.effective_end_date) = trunc(cv_papf_effective_end_date)         -- difference from c_emp_data cursor
-- for the case term and final processed on or before today, but final process date is later than actual term date need to use
-- cv_paaf_effective_end_date for pcaf table
              AND (   (TRUNC (pcaf.effective_end_date) =
                                            TRUNC (cv_papf_effective_end_date)
                      )
                   OR (TRUNC (pcaf.effective_end_date) =
                                            TRUNC (cv_paaf_effective_end_date)
                      )
                  )                       -- difference from c_emp_data cursor
-- Ken Mod 8/17/05 changed it not to drop any rows..
-- k AND     pcaf.COST_ALLOCATION_KEYFLEX_ID = pcak1.COST_ALLOCATION_KEYFLEX_ID
              AND pcaf.cost_allocation_keyflex_id = pcak1.cost_allocation_keyflex_id(+)
                                                                 -- mod by Ken
              AND papf.person_id = pcf.person_id(+)
-- Ken Mod 8/17/05 the following commented line never work, changed it not to drop any rows..
-- k AND     g_cut_off_date BETWEEN pcf.effective_start_date (+) AND pcf.effective_end_date (+) -- potentially need to use cv_papf dates
              AND (   (g_cut_off_date BETWEEN pcf.effective_start_date
                                          AND pcf.effective_end_date
                      )
                   OR (pcf.effective_start_date IS NULL)
                  )                                              -- mod by Ken
-- Ken Mod 8/17/05 changed it not to drop any rows..
-- k AND     PCF.STATUS = 'A-ACTIVE'
              AND (   pcf.status = 'A-ACTIVE'
                   OR pcf.status IS NULL
                  )                                              -- mod by Ken
--AND    papf.employee_number = '4000004'
         ORDER BY papf.employee_number;

      CURSOR c_pps_data
      IS
         SELECT   pps.period_of_service_id period_of_service_id
                , pps.person_id person_id, pps.date_start date_start
                , pps.accepted_termination_date accepted_termination_date
                , pps.actual_termination_date actual_termination_date
                , pps.final_process_date final_process_date
                , pps.last_standard_process_date last_standard_process_date
                , pps.leaving_reason leaving_reason
                , pps.notified_termination_date notified_termination_date
                , pps.projected_termination_date projected_termination_date
                , pps.last_update_date last_update_date
                , pps.creation_date creation_date
             --FROM hr.per_periods_of_service pps  --code commented by RXNETHI-ARGANO,16/05/23
             FROM apps.per_periods_of_service pps  --code added by RXNETHI-ARGANO,16/05/23
            WHERE pps.business_group_id = g_business_group_id
         ORDER BY pps.person_id, pps.period_of_service_id;

      CURSOR c_pps_emp_data
      IS
         SELECT DISTINCT pps.person_id
                    --FROM hr.per_periods_of_service pps  --code commented by RXNETHI-ARGANO,16/05/23
                    FROM apps.per_periods_of_service pps  --code added by RXNETHI-ARGANO,16/05/23
                ORDER BY pps.person_id;

-- Ken Mod ending.. 7/21/05 to capture pps data for each day, and used to calcualte term/rehire
      /*
	  START R12.2 Upgrade Remediation
	  code comented by RXNETHI-ARGANO,16/05/23
	  r_interface_mst               cust.ttec_spain_pay_interface_mst%ROWTYPE;
      r_interface_pps               cust.ttec_spain_pay_interface_pps%ROWTYPE;
	  */
	  --code added by RXNETHI-ARGANO,16/05/23
	  r_interface_mst               apps.ttec_spain_pay_interface_mst%ROWTYPE;
      r_interface_pps               apps.ttec_spain_pay_interface_pps%ROWTYPE;
	  --END R12.2 Upgrade Remediation
--r_interface_dep          cust.ttec_spain_pay_interface_dep%ROWTYPE;
--r_interface_abs          cust.ttec_spain_pay_interface_abs%ROWTYPE;
--r_interface_ele          cust.ttec_spain_pay_interface_ele%ROWTYPE;
      numerossocial                 VARCHAR2 (50);
      idcontratointerno             VARCHAR2 (50);
      epigrafe                      VARCHAR2 (50);
      clavepercepcion               VARCHAR2 (50);
      numerossocial_dt              DATE;
      idcontratointerno_dt          DATE;
      epigrafe_dt                   DATE;
      clavepercepcion_dt            DATE;
      v_extract_date                DATE                            := SYSDATE;
      v_term_his                    VARCHAR2 (1)                       := NULL;
      v_papf_effective_start_date   DATE                               := NULL;
      v_papf_effective_end_date     DATE                               := NULL;
      v_paaf_assignment_id          NUMBER (10)                        := NULL;
      v_paaf_effective_start_date   DATE                               := NULL;
      v_paaf_effective_end_date     DATE                               := NULL;
      v_period_of_service_id        NUMBER (9)                         := NULL;
      v_actual_termination_date     DATE                               := NULL;
      v_final_process_date          DATE                               := NULL;
      v_leaving_reason              VARCHAR2 (30)                      := NULL;
      v_date_start                  DATE                               := NULL;

      PROCEDURE get_mst_detail
      IS
      BEGIN
         --Fnd_File.put_line(Fnd_File.LOG,'get_mst_detail');
         --Fnd_File.put_line(Fnd_File.LOG,'Stage 12');
         BEGIN
            SELECT f.screen_entry_value, b.effective_start_date
              INTO idcontratointerno, idcontratointerno_dt
              FROM pay_element_types_f a
                 , pay_element_entries_f b
                 , pay_input_values_f c
                 , per_all_assignments_f d
                 , per_all_people_f e
                 , pay_element_entry_values_f f
             WHERE a.element_name = 'Social Security Details'  --'Tax Details'
               AND g_cut_off_date BETWEEN a.effective_start_date
                                      AND a.effective_end_date
               AND g_cut_off_date BETWEEN b.effective_start_date
                                      AND b.effective_end_date
               AND b.element_type_id = a.element_type_id
               AND a.element_type_id = c.element_type_id
               AND g_cut_off_date BETWEEN c.effective_start_date
                                      AND c.effective_end_date
               AND c.NAME = 'Contract Key'
               AND b.assignment_id = d.assignment_id
               AND d.primary_flag = 'Y'
               AND d.assignment_id = paaf_assignment_id
               AND b.effective_start_date BETWEEN d.effective_start_date
                                              AND d.effective_end_date
               AND e.person_id = d.person_id
               AND    --   E.EMPLOYEE_NUMBER  = r_papf_data.Oracle_employee_id
                   e.person_id = papf_person_id
               AND g_cut_off_date BETWEEN e.effective_start_date
                                      AND e.effective_end_date
               AND g_cut_off_date BETWEEN f.effective_start_date
                                      AND f.effective_end_date
               AND f.input_value_id = c.input_value_id
               AND f.element_entry_id = b.element_entry_id;
         EXCEPTION
            WHEN OTHERS
            THEN
               idcontratointerno := NULL;
               idcontratointerno_dt := NULL;
         END;

         r_interface_mst.idcontratointerno_dt := idcontratointerno_dt;

         --Fnd_File.put_line(Fnd_File.LOG,' 13');
         BEGIN
            SELECT f.screen_entry_value, b.effective_start_date
              INTO epigrafe, epigrafe_dt
              FROM pay_element_types_f a
                 , pay_element_entries_f b
                 , pay_input_values_f c
                 , per_all_assignments_f d
                 , per_all_people_f e
                 , pay_element_entry_values_f f
             WHERE a.element_name = 'Social Security Details'  --'Tax Details'
               AND g_cut_off_date BETWEEN a.effective_start_date
                                      AND a.effective_end_date
               AND g_cut_off_date BETWEEN b.effective_start_date
                                      AND b.effective_end_date
               AND b.element_type_id = a.element_type_id
               AND a.element_type_id = c.element_type_id
               AND g_cut_off_date BETWEEN c.effective_start_date
                                      AND c.effective_end_date
               AND c.NAME = 'SS Epigraph Code'
               AND b.assignment_id = d.assignment_id
               AND d.primary_flag = 'Y'
               AND d.assignment_id = paaf_assignment_id
               AND b.effective_start_date BETWEEN d.effective_start_date
                                              AND d.effective_end_date
               AND e.person_id = d.person_id
               AND    --   E.EMPLOYEE_NUMBER  = r_papf_data.Oracle_employee_id
                   e.person_id = papf_person_id
               AND g_cut_off_date BETWEEN e.effective_start_date
                                      AND e.effective_end_date
               AND g_cut_off_date BETWEEN f.effective_start_date
                                      AND f.effective_end_date
               AND f.input_value_id = c.input_value_id
               AND f.element_entry_id = b.element_entry_id;
         EXCEPTION
            WHEN OTHERS
            THEN
               epigrafe := NULL;
               epigrafe_dt := NULL;
         END;

         r_interface_mst.epigrafe := epigrafe;
         r_interface_mst.epigrafe_dt := epigrafe_dt;

         --Fnd_File.put_line(Fnd_File.LOG,'Stage 14');
         BEGIN
            SELECT f.screen_entry_value, b.effective_start_date
              INTO clavepercepcion, clavepercepcion_dt
              FROM pay_element_types_f a
                 , pay_element_entries_f b
                 , pay_input_values_f c
                 , per_all_assignments_f d
                 , per_all_people_f e
                 , pay_element_entry_values_f f
             WHERE a.element_name = 'Tax Details'
               AND g_cut_off_date BETWEEN a.effective_start_date
                                      AND a.effective_end_date
               AND g_cut_off_date BETWEEN b.effective_start_date
                                      AND b.effective_end_date
               AND b.element_type_id = a.element_type_id
               AND a.element_type_id = c.element_type_id
               AND g_cut_off_date BETWEEN c.effective_start_date
                                      AND c.effective_end_date
               AND c.NAME = 'Payment Key'
               AND b.assignment_id = d.assignment_id
               AND d.primary_flag = 'Y'
               AND d.assignment_id = paaf_assignment_id
               AND b.effective_start_date BETWEEN d.effective_start_date
                                              AND d.effective_end_date
               AND e.person_id = d.person_id
               AND    --   E.EMPLOYEE_NUMBER  = r_papf_data.Oracle_employee_id
                   e.person_id = papf_person_id
               AND g_cut_off_date BETWEEN e.effective_start_date
                                      AND e.effective_end_date
               AND g_cut_off_date BETWEEN f.effective_start_date
                                      AND f.effective_end_date
               AND f.input_value_id = c.input_value_id
               AND f.element_entry_id = b.element_entry_id;
         EXCEPTION
            WHEN OTHERS
            THEN
               clavepercepcion := NULL;
               clavepercepcion_dt := NULL;
         END;

         r_interface_mst.clave_percepcion := clavepercepcion;
         r_interface_mst.clavepercepcion_dt := clavepercepcion_dt;
         --Fnd_File.put_line(Fnd_File.LOG,'Stage 15');
         r_interface_mst.id_direccion := NULL;
         r_interface_mst.fecha_extra := NULL;
         r_interface_mst.clausulas_adicionales := NULL;
         r_interface_mst.condicion_desempleado := NULL;
         r_interface_mst.relacion_laboral_especial := NULL;
         r_interface_mst.causa_sustitucion := NULL;
         r_interface_mst.mujer_subrepresentda := NULL;
         r_interface_mst.incapacitado_readmitido := NULL;
         r_interface_mst.primer_trabajador_autonomo := NULL;
         r_interface_mst.exclusion_social := NULL;
         r_interface_mst.fic_especifico := NULL;
         r_interface_mst.numero_ss_sustituido := NULL;
         r_interface_mst.renta_active_insercion := NULL;
         r_interface_mst.mujer_mater_24_meses := NULL;
         r_interface_mst.mantiene_contrato_legal := NULL;
         r_interface_mst.contrato_relevo := NULL;
         r_interface_mst.mujer_reincorporada := NULL;
         r_interface_mst.excluido_fichero_afi := NULL;
         r_interface_mst.banco_emisor := '1';
         r_interface_mst.creation_date := g_cut_off_date;
         r_interface_mst.cut_off_date := g_cut_off_date;
         r_interface_mst.last_extract_date := SYSDATE;
         r_interface_mst.last_extract_file_type := ' PAYROLL RUN 1st';
         --Fnd_File.put_line(Fnd_File.LOG,'Stage 16');
         insert_interface_mst (ir_interface_mst => r_interface_mst);
      END;
   BEGIN
      fnd_file.put_line
         (fnd_file.LOG
        ,    'Starting to populate cust.ttec_spain_pay_interface_pps table...'
          || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS')
         );

      --DELETE FROM cust.ttec_spain_pay_interface_pps del  --code commented by RXNETHI-ARGANO,16/05/23
      DELETE FROM apps.ttec_spain_pay_interface_pps del    --code added by RXNETHI-ARGANO,16/05/23
            WHERE TRUNC (del.cut_off_date) = g_cut_off_date;

      FOR r_emp_data IN c_pps_data
      LOOP
         v_papf_effective_start_date := NULL;
         v_papf_effective_end_date := NULL;
         v_paaf_effective_start_date := NULL;
         v_paaf_effective_end_date := NULL;
         v_paaf_assignment_id := NULL;

         BEGIN
            -- term actual and processed at the same day, on or before today
            IF (    r_emp_data.actual_termination_date IS NOT NULL
                AND TRUNC (r_emp_data.actual_termination_date) =
                                         TRUNC (r_emp_data.final_process_date)
                AND TRUNC (r_emp_data.final_process_date) <=
                                                        TRUNC (v_extract_date)
               )
            THEN
               SELECT papf.effective_start_date, papf.effective_end_date
                 INTO v_papf_effective_start_date, v_papf_effective_end_date
                 --FROM hr.per_all_people_f papf  --code commented by RXNETHI-ARGANO,16/05/23
                 FROM apps.per_all_people_f papf  --code added by RXNETHI-ARGANO,16/05/23
                WHERE r_emp_data.person_id = papf.person_id
                  AND TRUNC (r_emp_data.actual_termination_date) =
                                               TRUNC (papf.effective_end_date);
            END IF;

            -- term actual and processed NOT at the same day, on or before today
            IF (    r_emp_data.actual_termination_date IS NOT NULL
                AND TRUNC (r_emp_data.actual_termination_date) !=
                                         TRUNC (r_emp_data.final_process_date)
                AND TRUNC (r_emp_data.final_process_date) <=
                                                        TRUNC (v_extract_date)
               )
            THEN
               SELECT papf.effective_start_date, papf.effective_end_date
                 INTO v_papf_effective_start_date, v_papf_effective_end_date
                 --FROM hr.per_all_people_f papf --code commented by RXNETHI-ARGANO,16/05/23
                 FROM apps.per_all_people_f papf --code added by RXNETHI-ARGANO,16/05/23
                WHERE r_emp_data.person_id = papf.person_id
                  AND TRUNC (r_emp_data.actual_termination_date) =
                                               TRUNC (papf.effective_end_date);
            END IF;

            -- term actual and processed NOT at the same day, and final process date is later than today
            IF (    r_emp_data.actual_termination_date IS NOT NULL
                AND TRUNC (r_emp_data.actual_termination_date) !=
                                         TRUNC (r_emp_data.final_process_date)
                AND TRUNC (r_emp_data.final_process_date) >
                                                        TRUNC (v_extract_date)
               )
            THEN
               SELECT papf.effective_start_date, papf.effective_end_date
                 INTO v_papf_effective_start_date, v_papf_effective_end_date
                 --FROM hr.per_all_people_f papf  --code commented by RXNETHI-ARGANO,16/05/23
                 FROM apps.per_all_people_f papf  --code added by RXNETHI-ARGANO,16/05/23
                WHERE r_emp_data.person_id = papf.person_id
                  AND TRUNC (r_emp_data.actual_termination_date) =
                                               TRUNC (papf.effective_end_date);
            END IF;

            -- no term at all or Rehired normally or term and rehied on or before today.
            IF (r_emp_data.actual_termination_date IS NULL)
            THEN
               SELECT papf.effective_start_date, papf.effective_end_date
                 INTO v_papf_effective_start_date, v_papf_effective_end_date
                 --FROM hr.per_all_people_f papf  --code commented by RXNETHI-ARGANO,16/05/23
                 FROM apps.per_all_people_f papf  --code added by RXNETHI-ARGANO,16/05/23
                WHERE r_emp_data.person_id = papf.person_id
                  AND TRUNC (v_extract_date)
                         BETWEEN TRUNC (papf.effective_start_date)
                             AND TRUNC (papf.effective_end_date);
            END IF;
         EXCEPTION
            WHEN OTHERS
            THEN
               v_papf_effective_start_date := NULL;
               v_papf_effective_end_date := NULL;
         END;

         BEGIN
            -- term actual and processed at the same day, on or before today
            IF (    r_emp_data.actual_termination_date IS NOT NULL
                AND TRUNC (r_emp_data.actual_termination_date) =
                                         TRUNC (r_emp_data.final_process_date)
                AND TRUNC (r_emp_data.final_process_date) <=
                                                        TRUNC (v_extract_date)
               )
            THEN
               SELECT paaf.assignment_id, paaf.effective_start_date
                    , paaf.effective_end_date
                 INTO v_paaf_assignment_id, v_paaf_effective_start_date
                    , v_paaf_effective_end_date
                 --FROM hr.per_all_assignments_f paaf  --code commented by RXNETHI-ARGANO,16/05/23
                 FROM apps.per_all_assignments_f paaf  --code added by RXNETHI-ARGANO,16/05/23
                WHERE r_emp_data.person_id = paaf.person_id
                  AND TRUNC (r_emp_data.actual_termination_date) =
                                               TRUNC (paaf.effective_end_date);
            END IF;

            -- term actual and processed NOT at the same day, on or before today
            IF (    r_emp_data.actual_termination_date IS NOT NULL
                AND TRUNC (r_emp_data.actual_termination_date) !=
                                         TRUNC (r_emp_data.final_process_date)
                AND TRUNC (r_emp_data.final_process_date) <=
                                                        TRUNC (v_extract_date)
               )
            THEN
               SELECT paaf.assignment_id, paaf.effective_start_date
                    , paaf.effective_end_date
                 INTO v_paaf_assignment_id, v_paaf_effective_start_date
                    , v_paaf_effective_end_date
                 --FROM hr.per_all_assignments_f paaf  --code commented by RXNETHI-ARGANO,16/05/23
                 FROM apps.per_all_assignments_f paaf  --code added by RXNETHI-ARGANO,16/05/23
                WHERE r_emp_data.person_id = paaf.person_id
                  AND TRUNC (r_emp_data.final_process_date) =
                                               TRUNC (paaf.effective_end_date);
            END IF;

            -- term actual and processed NOT at the same day, and final process date is later than today
            IF (    r_emp_data.actual_termination_date IS NOT NULL
                AND TRUNC (r_emp_data.actual_termination_date) !=
                                         TRUNC (r_emp_data.final_process_date)
                AND TRUNC (r_emp_data.final_process_date) >
                                                        TRUNC (v_extract_date)
               )
            THEN
               SELECT paaf.assignment_id, paaf.effective_start_date
                    , paaf.effective_end_date
                 INTO v_paaf_assignment_id, v_paaf_effective_start_date
                    , v_paaf_effective_end_date
                 --FROM hr.per_all_assignments_f paaf  --code commented by RXNETHI-ARGANO,16/05/23
                 FROM apps.per_all_assignments_f paaf  --code added by RXNETHI-ARGANO,16/05/23
                WHERE r_emp_data.person_id = paaf.person_id
                  AND TRUNC (r_emp_data.final_process_date) =
                                               TRUNC (paaf.effective_end_date);
            END IF;

            -- no term at all or Rehired normally or term and rehied on or before today.
            IF (r_emp_data.actual_termination_date IS NULL)
            THEN
               SELECT paaf.assignment_id, paaf.effective_start_date
                    , paaf.effective_end_date
                 INTO v_paaf_assignment_id, v_paaf_effective_start_date
                    , v_paaf_effective_end_date
                 --FROM hr.per_all_assignments_f paaf  --code commented by RXNETHI-ARGANO,16/05/23
                 FROM apps.per_all_assignments_f paaf  --code added by RXNETHI-ARGANO,16/05/23
                WHERE r_emp_data.person_id = paaf.person_id
                  AND TRUNC (v_extract_date)
                         BETWEEN TRUNC (paaf.effective_start_date)
                             AND TRUNC (paaf.effective_end_date);
            END IF;
         EXCEPTION
            WHEN OTHERS
            THEN
               v_paaf_assignment_id := NULL;
               v_paaf_effective_start_date := NULL;
               v_paaf_effective_end_date := NULL;
         END;

         r_interface_pps.period_of_service_id :=
                                               r_emp_data.period_of_service_id;
         r_interface_pps.person_id := r_emp_data.person_id;
         r_interface_pps.date_start := r_emp_data.date_start;
         r_interface_pps.accepted_termination_date :=
                                          r_emp_data.accepted_termination_date;
         r_interface_pps.actual_termination_date :=
                                            r_emp_data.actual_termination_date;
         r_interface_pps.final_process_date := r_emp_data.final_process_date;
         r_interface_pps.last_standard_process_date :=
                                         r_emp_data.last_standard_process_date;
         r_interface_pps.leaving_reason := r_emp_data.leaving_reason;
         r_interface_pps.notified_termination_date :=
                                          r_emp_data.notified_termination_date;
         r_interface_pps.projected_termination_date :=
                                         r_emp_data.projected_termination_date;
         r_interface_pps.last_update_date := r_emp_data.last_update_date;
         r_interface_pps.creation_date := r_emp_data.creation_date;
         r_interface_pps.cut_off_date := g_cut_off_date;
         r_interface_pps.papf_effective_start_date :=
                                                   v_papf_effective_start_date;
         r_interface_pps.papf_effective_end_date := v_papf_effective_end_date;
         r_interface_pps.paaf_effective_start_date :=
                                                   v_paaf_effective_start_date;
         r_interface_pps.paaf_effective_end_date := v_paaf_effective_end_date;
         r_interface_pps.paaf_assignment_id := v_paaf_assignment_id;
         r_interface_pps.extract_date := v_extract_date;
         insert_interface_pps (ir_interface_pps => r_interface_pps);
      END LOOP;                                                  -- c_pps_data

      COMMIT;
      fnd_file.put_line
         (fnd_file.LOG
        ,    'Finished to populate cust.ttec_spain_pay_interface_pps table...'
          || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS')
         );
      fnd_file.put_line
         (fnd_file.LOG
        ,    'Starting to populate cust.ttec_spain_pay_interface_MST table - 1st pass...'
          || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS')
         );

      --DELETE FROM cust.ttec_spain_pay_interface_mst del  --code commented by RXNETHI-ARGANO,16/05/23
      DELETE FROM apps.ttec_spain_pay_interface_mst del    --code added by RXNETHI-ARGANO,16/05/23
            WHERE TRUNC (del.cut_off_date) = g_cut_off_date;

      FOR r_papf_data IN c_papf_data
      LOOP
         papf_person_id := r_papf_data.person_id;
         r_interface_mst.employee_id := r_papf_data.employee_id;
--         fnd_file.put_line (fnd_file.LOG
--                          ,    'c_pcaf_data FOUND ->'
--                            || papf_person_id
--                            || 'Employee_number ->'
--                            || r_papf_data.employee_id
--                           );
         r_interface_mst.last_name := r_papf_data.last_name;
         r_interface_mst.second_last_name := r_papf_data.second_last_name;
         r_interface_mst.first_name := r_papf_data.first_name;
         r_interface_mst.birth_date := r_papf_data.birth_date;
         r_interface_mst.gender := r_papf_data.gender;
         r_interface_mst.treatment := r_papf_data.treatment;
         r_interface_mst.nationality := r_papf_data.nationality;
         r_interface_mst.nif_value := r_papf_data.nif_value;
         r_interface_mst.nie := r_papf_data.nie;
         r_interface_mst.irpf := r_papf_data.irpf;
         --r_interface_mst.country          := r_papf_data.country;
         r_interface_mst.ordinal_periodo := r_papf_data.ordinal_periodo;
         r_interface_mst.fecha_antiguedad := r_papf_data.fecha_antiguedad;
         r_interface_mst.tipo_empleado := r_papf_data.tipo_empleado;
         r_interface_mst.legal_employer := r_papf_data.legal_employer;
         r_interface_mst.work_center := r_papf_data.work_center;
         r_interface_mst.tax_id := r_papf_data.tax_id;
         r_interface_mst.person_type := r_papf_data.person_type;
         r_interface_mst.person_creation_date :=
                                              r_papf_data.person_creation_date;
         r_interface_mst.person_update_date := r_papf_data.person_update_date;
         r_interface_mst.person_id := r_papf_data.person_id;
         r_interface_mst.party_id := r_papf_data.party_id;
         r_interface_mst.person_type_id := r_papf_data.person_type_id;
         r_interface_mst.system_person_type := r_papf_data.system_person_type;
         r_interface_mst.user_person_type := r_papf_data.user_person_type;
         r_interface_mst.fecha_de_incorporacion :=
                                            r_papf_data.fecha_de_incorporacion;
                                      -- WO#150091  added By C.Chan 12/22/2005
         r_interface_mst.original_date_of_hire :=
                                             r_papf_data.original_date_of_hire;
                                                    -- added by CC on 3/8/2006
         r_interface_mst.marital_status := r_papf_data.marital_status;
                                      -- WO#131875  added By C.Chan 09/21/2005

         BEGIN
            SELECT addr.date_from address_date_start
                 , addr.address_line1 address_line1
                 , addr.address_line2 address_line2
                 , addr.town_or_city region_1, addr.postal_code postal_code
                 , DECODE (addr.address_line3, NULL, '0', addr.address_line3)
                                                                address_line3
                 , addr.telephone_number_1 telephone1
                                        -- WO#144030 added By C.Chan 2/21/2005
                 , addr.telephone_number_2 telephone2
                                        -- WO#144030 added By C.Chan 2/21/2005
                 , addr.last_update_date address_update_date
                 , addr.country
              INTO r_interface_mst.address_date_start
                 , r_interface_mst.address_line1
                 , r_interface_mst.address_line2
                 , r_interface_mst.region_1, r_interface_mst.postal_code
                 , r_interface_mst.address_line3
                 , r_interface_mst.telephone1
                 , r_interface_mst.telephone2
                 , r_interface_mst.address_update_date
                 , r_interface_mst.country
              --FROM hr.per_addresses addr  --code commented by RXNETHI-ARGANO,16/05/23
              FROM apps.per_addresses addr    --code added by RXNETHI-ARGANO,16/05/23
             WHERE business_group_id = g_business_group_id
               AND addr.person_id = papf_person_id
               AND g_cut_off_date BETWEEN addr.date_from
                                      AND NVL (addr.date_to, SYSDATE)
               AND UPPER (addr.primary_flag(+)) = 'Y';
         --  Fnd_File.put_line(Fnd_File.LOG,'Fetch Address Succssess');
         EXCEPTION
            WHEN OTHERS
            THEN
               r_interface_mst.address_date_start := NULL;
               r_interface_mst.address_line1 := NULL;
               r_interface_mst.address_line2 := NULL;
               r_interface_mst.region_1 := NULL;
               r_interface_mst.postal_code := NULL;
               r_interface_mst.address_line3 := NULL;
               r_interface_mst.telephone1 := NULL;
               r_interface_mst.telephone2 := NULL;
               r_interface_mst.address_update_date := NULL;
         --Fnd_File.put_line(Fnd_File.LOG,'Fetch Address Fail');
         END;

          --
         -- Added by C. Chan 8/30/2006 WO#217631
         --
         BEGIN
            SELECT   DECODE (CATEGORY
                           , 'ES_DIS_BTW_33_65_PERC', 'M_33_65'
                           , 'ES_DIS_BTW_33_65_PERC_ASSISTAN', 'M_33_65_A'
                           , 'ES_DIS_GT_65_PERC', 'M_65'
                           , 'UNKNOWN'
                            )
                INTO r_interface_mst.disability
                --FROM hr.per_disabilities_f  --code commented by RXNETHI-ARGANO,16/05/23
                FROM apps.per_disabilities_f  --code added by RXNETHI-ARGANO,16/05/23
               WHERE person_id = papf_person_id
                 AND g_cut_off_date BETWEEN effective_start_date
                                        AND effective_end_date
                 AND ROWNUM < 2
            ORDER BY last_update_date DESC;
         EXCEPTION
            WHEN OTHERS
            THEN
               r_interface_mst.disability := NULL;
         END;

         paaf_row_count := 0;
         cursor_exist := NULL;

         SELECT COUNT (*)
           INTO paaf_row_count
           --FROM hr.per_all_assignments_f paaf   --code commented by RXNETHI-ARGANO,16/05/23
           FROM apps.per_all_assignments_f paaf   --code added by RXNETHI-ARGANO,16/05/23
          WHERE paaf.business_group_id = g_business_group_id
            AND paaf.person_id = papf_person_id
            AND g_cut_off_date BETWEEN paaf.effective_start_date
                                   AND paaf.effective_end_date;

         IF paaf_row_count > 0
         THEN
            cursor_exist := 'EXIST';
         ELSE
            cursor_exist := 'NOT EXIST';
         END IF;

         paaf_assignment_id := NULL;
         paaf_period_of_service_id := NULL;
         paaf_effective_start_date := NULL;
         paaf_payroll_id := NULL;
         paaf_job_id := NULL;
         paaf_organization_id := NULL;
         paaf_soft_coding_keyflex_id := NULL;
         paaf_location_id := NULL;
         paaf_effective_end_date := NULL;
         paaf_effective_start_date := NULL;
         r_interface_mst.ass_eff_date := NULL;
         r_interface_mst.pago_gestiontiempo := NULL;
         r_interface_mst.modelo_de_referencia := NULL;
         r_interface_mst.normal_hours := NULL;
         r_interface_mst.convenio := NULL;
         r_interface_mst.tipo_salario := NULL;
         r_interface_mst.tipo_de_ajuste := NULL;
         r_interface_mst.job_id := NULL;
         r_interface_mst.nivel_salarial := NULL;
         r_interface_mst.assignment_id := NULL;
         r_interface_mst.assignment_creation_date := NULL;
         r_interface_mst.assignment_update_date := NULL;
         r_interface_mst.assignment_status := NULL;                    -- V1.0

         FOR r_paaf_data IN c_paaf_data
         LOOP
--            fnd_file.put_line (fnd_file.LOG
--                             , 'c_paaf_data FOUND ->' || papf_person_id
--                              );
            paaf_assignment_id := r_paaf_data.assignment_id;
            paaf_period_of_service_id := r_paaf_data.period_of_service_id;
            paaf_effective_start_date := r_paaf_data.effective_start_date;
            paaf_payroll_id := r_paaf_data.payroll_id;
            paaf_job_id := r_paaf_data.job_id;
            paaf_organization_id := r_paaf_data.organization_id;
            paaf_soft_coding_keyflex_id := r_paaf_data.soft_coding_keyflex_id;
            paaf_location_id := r_paaf_data.location_id;
            paaf_effective_end_date := r_paaf_data.effective_end_date;
            paaf_effective_start_date := r_paaf_data.effective_start_date;
            r_interface_mst.ass_eff_date := r_paaf_data.ass_eff_date;
            r_interface_mst.pago_gestiontiempo :=
                                                r_paaf_data.pago_gestiontiempo;
            r_interface_mst.modelo_de_referencia :=
                                              r_paaf_data.modelo_de_referencia;
            r_interface_mst.normal_hours := r_paaf_data.normal_hours;
            r_interface_mst.convenio := r_paaf_data.convenio;
            r_interface_mst.tipo_salario := r_paaf_data.tipo_salario;
            r_interface_mst.tipo_de_ajuste := r_paaf_data.tipo_de_ajuste;
            r_interface_mst.job_id := r_paaf_data.legacy_job_id;
            r_interface_mst.nivel_salarial := r_paaf_data.nivel_salarial;
            r_interface_mst.assignment_id := r_paaf_data.assignment_id;
            r_interface_mst.assignment_creation_date :=
                                          r_paaf_data.assignment_creation_date;
            r_interface_mst.assignment_update_date :=
                                            r_paaf_data.assignment_update_date;
            r_interface_mst.assignment_status := r_paaf_data.assignment_status;
                                                                       -- V1.0
            --CC
            --Added By C. Chan for WO#293166 on Aug 08,2007
            r_interface_mst.centro_de_trabajo := NULL;
            r_interface_mst.departmento := NULL;
            r_interface_mst.centros_de_coste := NULL;
            r_interface_mst.costsegment_dt := NULL;
            r_interface_mst.pcaf_update_date := NULL;
            r_interface_mst.costing_pct := NULL;

            FOR r_pcak_data IN c_pcak_data
            LOOP
--               fnd_file.put_line (fnd_file.LOG
--                                , 'c_pcak_data FOUND ->' || papf_person_id
--                                 );
               --Added By C. Chan for WO#293166 on Aug 08,2007
               r_interface_mst.centro_de_trabajo :=
                                                 r_pcak_data.centro_de_trabajo;
               r_interface_mst.departmento := r_pcak_data.departmento;
               r_interface_mst.centros_de_coste :=
                                                  r_pcak_data.centros_de_coste;
               r_interface_mst.costsegment_dt := r_pcak_data.costsegment_dt;
               r_interface_mst.pcaf_update_date :=
                                                  r_pcak_data.pcaf_update_date;
               r_interface_mst.costing_pct := r_pcak_data.costing_pct;

               BEGIN
                  SELECT f.screen_entry_value, b.effective_start_date
                    INTO numerossocial, numerossocial_dt
                    FROM pay_element_types_f a
                       , pay_element_entries_f b
                       , pay_input_values_f c
                       , per_all_assignments_f d
                       , per_all_people_f e
                       , pay_element_entry_values_f f
                   WHERE a.element_name =
                                      'Social Security Details'
                                                               --'Tax Details'
                     AND g_cut_off_date BETWEEN a.effective_start_date
                                            AND a.effective_end_date
                     AND g_cut_off_date BETWEEN b.effective_start_date
                                            AND b.effective_end_date
                     AND b.element_type_id = a.element_type_id
                     AND a.element_type_id = c.element_type_id
                     AND g_cut_off_date BETWEEN c.effective_start_date
                                            AND c.effective_end_date
                     AND c.NAME = 'Social Security Identifier'
                     AND b.assignment_id = d.assignment_id
                     AND d.primary_flag = 'Y'
                     AND d.assignment_id = paaf_assignment_id
                     AND b.effective_start_date BETWEEN d.effective_start_date
                                                    AND d.effective_end_date
                     AND e.person_id = d.person_id
                     AND
                      --   E.EMPLOYEE_NUMBER  = r_papf_data.Oracle_employee_id
                         e.person_id = papf_person_id
                     AND g_cut_off_date BETWEEN e.effective_start_date
                                            AND e.effective_end_date
                     AND g_cut_off_date BETWEEN f.effective_start_date
                                            AND f.effective_end_date
                     AND f.input_value_id = c.input_value_id
                     AND f.element_entry_id = b.element_entry_id;
               --Fnd_File.put_line(Fnd_File.LOG,'c_SSC FOUND ->'|| papf_person_id);
               EXCEPTION
                  WHEN OTHERS
                  THEN
                     numerossocial := NULL;
                     numerossocial_dt := NULL;
               END;

               r_interface_mst.numero_s_social := numerossocial;
               r_interface_mst.numerossocial_dt := numerossocial_dt;
               --fnd_file.put_line (fnd_file.LOG, 'Stage 1');

               IF paaf_period_of_service_id IS NOT NULL
               THEN
                  BEGIN
                     SELECT pps.period_of_service_id period_of_service_id
                          , pps.date_start date_start
                          , pps.actual_termination_date
                                                      actual_termination_date
                          , pps.notified_termination_date
                                                    notified_termination_date
                                      -- WO#150091  added By C.Chan 12/21/2005
                          , pps.leaving_reason leaving_reason
                          , pps.last_update_date pps_update_date
                       INTO r_interface_mst.period_of_service_id
                          , r_interface_mst.date_start
                          , r_interface_mst.actual_termination_date
                          , r_interface_mst.notified_termination_date
                          ,           -- WO#150091  added By C.Chan 12/21/2005
                            r_interface_mst.leaving_reason
                          , r_interface_mst.pps_update_date
                       --FROM hr.per_periods_of_service pps  --code commented by RXNETHI-ARGANO,16/05/23
                       FROM apps.per_periods_of_service pps    --code added by RXNETHI-ARGANO,16/05/23
                      WHERE pps.person_id = papf_person_id
                        AND pps.period_of_service_id =
                                                     paaf_period_of_service_id;

--                     fnd_file.put_line (fnd_file.LOG
--                                      ,    'c_period_of_service FOUND ->'
--                                        || papf_person_id
--                                       );

                     --
                     -- Added by C.Chan on April 01, 2008 for WO#431198
                     --
                     IF r_interface_mst.leaving_reason IS NOT NULL
                     THEN
                        BEGIN
                           SELECT attribute4
                             INTO r_interface_mst.leaving_reason
                             FROM fnd_lookup_values
                            WHERE lookup_type = 'LEAV_REAS'
                              AND lookup_code = r_interface_mst.leaving_reason
                              AND LANGUAGE = 'US';
                        --Fnd_File.put_line(Fnd_File.LOG,'LEAV_REAS FOUND ->'|| papf_person_id);
                        EXCEPTION
                           WHEN OTHERS
                           THEN
                              NULL;
                        END;
                     END IF;
                  EXCEPTION
                     WHEN OTHERS
                     THEN
                        r_interface_mst.period_of_service_id := NULL;
                        r_interface_mst.date_start := NULL;
                        r_interface_mst.actual_termination_date := NULL;
                        r_interface_mst.notified_termination_date := NULL;
                        r_interface_mst.leaving_reason := NULL;
                        r_interface_mst.pps_update_date := NULL;
                  END;
               ELSE
                  r_interface_mst.period_of_service_id := NULL;
                  r_interface_mst.date_start := NULL;
                  r_interface_mst.actual_termination_date := NULL;
                  r_interface_mst.notified_termination_date := NULL;
                  r_interface_mst.leaving_reason := NULL;
                  r_interface_mst.pps_update_date := NULL;
               END IF;

               /*
                V 1.0  Begin

                 If employee's assigment status is 'Excedencia%'
                 Then,
                   Need to replicate the termination derived from
                   the assignment status -> Excedencia%

                      Set 1. actual_termination_date with assignment effective date

                          2. leaving_reason with leaving reason code derived from Exedencia
                             assignment status code.
               */
               IF r_paaf_data.assignment_status LIKE 'Excedencia%'
               THEN
                  BEGIN
                     SELECT attribute4
                       INTO r_interface_mst.leaving_reason
                       FROM fnd_lookup_values
                      WHERE lookup_type = 'LEAV_REAS'
                        AND description LIKE
                                   '%' || r_paaf_data.assignment_status || '%'
                        AND LANGUAGE = 'US';

--                     fnd_file.put_line (fnd_file.LOG
--                                      , 'LEAV_REAS FOUND ->' || papf_person_id
--                                       );
                  EXCEPTION
                     WHEN OTHERS
                     THEN
                        NULL;
                        fnd_file.put_line
                           (fnd_file.LOG
                          ,    'Invalid ASSIGNMENT_STATUS: Cannot find the matching LEAV_REAS code on Excedencia, please verify spelling of ASSIGNMENT_STATUS ->['
                            || r_paaf_data.assignment_status
                            || '] and make sure it match the value in LOOKUP meaning on LEAV_REAS. Person_id ->['
                            || papf_person_id ||']'
                           );
                  END;

                  r_interface_mst.actual_termination_date :=
                                              r_paaf_data.effective_start_date;
                  r_interface_mst.notified_termination_date := NULL;
               ELSE /* V1.1  Begin */

                  -- Need to verify if there is any ASSIGNMENT STATUS with Excedencia on future date
                  --
                  BEGIN

                       SELECT paaf.effective_start_date,asttl.user_status assignment_status
                       INTO r_interface_mst.actual_termination_date,r_interface_mst.assignment_status
                       --FROM hr.per_all_assignments_f paaf  --code commented by RXNETHI-ARGANO,16/05/23
                       FROM apps.per_all_assignments_f paaf  --code added by RXNETHI-ARGANO,16/05/23
                          , per_assignment_status_types_tl asttl
                      WHERE paaf.business_group_id = g_business_group_id
                        AND paaf.person_id = papf_person_id
                        AND paaf.assignment_status_type_id =
                                                   asttl.assignment_status_type_id

                        AND asttl.LANGUAGE = 'US'
                        AND paaf.effective_start_date >= g_cut_off_date
                        AND asttl.user_status LIKE 'Excedencia%'
                        AND ROWNUM < 2
                        ORDER BY paaf.effective_start_date;


                        r_interface_mst.notified_termination_date := NULL;

                        BEGIN
                         SELECT attribute4
                           INTO r_interface_mst.leaving_reason
                           FROM fnd_lookup_values
                          WHERE lookup_type = 'LEAV_REAS'
                            AND description LIKE
                                       '%' || r_interface_mst.assignment_status || '%'
                            AND LANGUAGE = 'US';

                        EXCEPTION
                         WHEN OTHERS
                         THEN
                            NULL;
                            fnd_file.put_line
                               (fnd_file.LOG
                              ,    'Invalid ASSIGNMENT_STATUS_2: Cannot find the matching LEAV_REAS code on Excedencia, please verify spelling of ASSIGNMENT_STATUS ->['
                                || r_paaf_data.assignment_status
                                || '] and make sure it match the value in LOOKUP meaning on LEAV_REAS. Person_id ->['
                                || papf_person_id ||']'
                               );
                        END;

                  EXCEPTION
                     WHEN OTHERS
                     THEN
                       NULL;
                  END;
                  /* V1.1  End */
               END IF;

               /* V 1.0 End */
             --  fnd_file.put_line (fnd_file.LOG, 'Stage 2');

               IF paaf_job_id IS NOT NULL
               THEN
                  BEGIN
                     SELECT SUBSTR (pj.NAME, 1, INSTR (pj.NAME, '.') - 1)
                                                                   new_job_id
                       INTO r_interface_mst.new_job_id
                       --FROM hr.per_jobs pj  --code commented by RXNETHI-ARGANO,16/05/23
                       FROM apps.per_jobs pj  --code added by RXNETHI-ARGANO,16/05/23
                      WHERE pj.job_id = paaf_job_id;
                  EXCEPTION
                     WHEN OTHERS
                     THEN
                        r_interface_mst.new_job_id := NULL;
                  END;
               ELSE
                  r_interface_mst.new_job_id := NULL;
               END IF;

               --fnd_file.put_line (fnd_file.LOG, 'Stage 3');

               BEGIN
                  SELECT LTRIM (TO_CHAR (ppp.proposed_salary_n
                                       , '999999999999.99'
                                        )
                               ) salary
                       , ppp.change_date salary_change_date
                       , ppp.last_update_date salary_update_date
                    INTO r_interface_mst.salary
                       , r_interface_mst.salary_change_date
                       , r_interface_mst.salary_update_date
                    FROM per_pay_proposals ppp
                   WHERE ppp.assignment_id = paaf_assignment_id
                     AND NVL (ppp.change_date
                            , TO_DATE ('2000-01-01', 'yyyy-mm-dd')
                             ) =
                            (SELECT NVL (MAX (change_date)
                                       , TO_DATE ('2000-01-01', 'yyyy-mm-dd')
                                        )
                               FROM per_pay_proposals ppp1
                              WHERE ppp1.assignment_id = ppp.assignment_id
                                AND ppp1.approved = 'Y'
                                AND ppp1.change_date <= g_cut_off_date);
               EXCEPTION
                  WHEN OTHERS
                  THEN
                     r_interface_mst.salary := NULL;
                     r_interface_mst.salary_change_date := NULL;
                     r_interface_mst.salary_update_date := NULL;
               END;

               --fnd_file.put_line (fnd_file.LOG, 'Stage 4');

               IF paaf_payroll_id IS NOT NULL
               THEN
                  BEGIN
                     SELECT ppayf.payroll_id payroll_id
                          , ppayf.payroll_name payroll_name
                       --    ,ppayf.COST_ALLOCATION_KEYFLEX_ID
                     INTO   r_interface_mst.payroll_id
                          , r_interface_mst.payroll_name
                       --FROM hr.pay_all_payrolls_f ppayf  --code commented by RXNETHI-ARGANO,16/05/23
                       FROM apps.pay_all_payrolls_f ppayf  --code added by RXNETHI-ARGANO,16/05/23
                      WHERE ppayf.payroll_id = paaf_payroll_id
                        AND TRUNC (paaf_effective_start_date)
                               BETWEEN ppayf.effective_start_date
                                   AND ppayf.effective_end_date;
                  EXCEPTION
                     WHEN OTHERS
                     THEN
                        r_interface_mst.payroll_id := NULL;
                        r_interface_mst.payroll_name := NULL;
                  END;
               ELSE
                  r_interface_mst.payroll_id := NULL;
                  r_interface_mst.payroll_name := NULL;
               END IF;

               --fnd_file.put_line (fnd_file.LOG, 'Stage 5');

               IF paaf_soft_coding_keyflex_id IS NOT NULL
               THEN
                  BEGIN
                     SELECT hsck.segment5 grupo_tarifa
/* Commented out By C. Chan for WO#293166 on Aug 08,2007
         ,DECODE(hsck.SEGMENT2,2230,35,1969,30,1821,1,1826,15,1827,16,1841,17,1842,18
                              ,1828,19,1822,2,1843,20,1829,21,1830,27,1831,28
                              ,1832,29,1844,3,1833,31,1823,4,1824,5,1825,7,NULL)  centro_de_trabajo
*/
                     INTO   r_interface_mst.grupo_tarifa
--             ,r_interface_mst.centro_de_trabajo
                     --FROM   hr.hr_soft_coding_keyflex hsck  --code commented by RXNETHI-ARGANO,16/05/23
                     FROM   apps.hr_soft_coding_keyflex hsck  --code added by RXNETHI-ARGANO,16/05/23
                      WHERE hsck.soft_coding_keyflex_id =
                                                   paaf_soft_coding_keyflex_id;
                  EXCEPTION
                     WHEN OTHERS
                     THEN
                        r_interface_mst.grupo_tarifa := NULL;
                  --          r_interface_mst.centro_de_trabajo := NULL;
                  END;
               ELSE
                  r_interface_mst.grupo_tarifa := NULL;
               --         r_interface_mst.centro_de_trabajo := NULL;
               END IF;

               --fnd_file.put_line (fnd_file.LOG, 'Stage 6');
/* --CC
      IF paaf_location_id IS NOT NULL
      THEN
      BEGIN
         SELECT
            DECODE(pcak.segment3 ,'005','1',
                                  '020','2',
                                   '085','3',
                                   '040','4',
                                   '055','5',
                                   '060','6',
                                   '015','7',
                                   '090','8',
                                   '045','10',
                                   '056','11' , pcak.segment3 )       departmento
,          DECODE(pcak1.segment1,NULL,hla.attribute2,pcak1.segment1)
         ||pcak1.segment2
         ||DECODE(pcak1.segment3,NULL,pcak.segment3,pcak1.segment3)  centros_de_coste
         ,pcaf.effective_start_date                                  CostSegment_dt
       ,pcaf.last_update_date                                      pcaf_update_date
       INTO    r_interface_mst.departmento,
               r_interface_mst.centros_de_coste,
               r_interface_mst.CostSegment_dt,
            r_interface_mst.pcaf_update_date
         FROM pay_cost_allocation_keyflex            pcak
            , hr_all_organization_units              haou
            , hr_locations_all                       hla
            , pay_cost_allocations_f                 pcaf
            , pay_cost_allocation_keyflex            pcak1
         WHERE hla.location_id  = paaf_location_id
         AND pcaf.assignment_id = paaf_assignment_id
         AND pcak.COST_ALLOCATION_KEYFLEX_ID = haou.COST_ALLOCATION_KEYFLEX_ID
         AND haou.organization_id  = 1840
         AND pcak1.COST_ALLOCATION_KEYFLEX_ID = pcaf.COST_ALLOCATION_KEYFLEX_ID
         AND TRUNC(paaf_effective_start_date) BETWEEN pcaf.effective_start_date AND pcaf.effective_end_date;
      EXCEPTION WHEN OTHERS THEN
               r_interface_mst.departmento      := NULL;
               r_interface_mst.centros_de_coste := NULL;
               r_interface_mst.CostSegment_dt   := NULL;
            r_interface_mst.pcaf_update_date := NULL;
      END;
      ELSE
               r_interface_mst.departmento      := NULL;
               r_interface_mst.centros_de_coste := NULL;
               r_interface_mst.CostSegment_dt   := NULL;
            r_interface_mst.pcaf_update_date := NULL;
      END IF;
*/
               --fnd_file.put_line (fnd_file.LOG, 'Stage 7');

               BEGIN
                  SELECT pppm.external_account_id pppm_external_account_id
                       --  ,DECODE(pppm.ORG_PAYMENT_METHOD_ID,175,2,174,3,176,4,171,2,172,3,173,4,NULL)  tipo_de_pago
                  ,      DECODE (popm.org_payment_method_name
                               , 'Banco de UTE TT-Cmt-Cheque', 2
                               , 'Banco de UTE TT-Cmt-Caja', 3
                               , 'Banco de UTE TT-Cmt-TB', 4
                               , 'Banco de Teletech-Cheque', 2
                               , 'Banco de Teletech-Caja', 3
                               , 'Banco de Teletech-TB', 4
                               , 'Banco de Kirkwood @Home', 4
                               , NULL
                                ) tipo_de_pago
                       , pppm.effective_start_date pppm_effective_date
                    INTO pppm_external_account_id
                       , r_interface_mst.tipo_de_pago
                       , r_interface_mst.pppm_effective_date
                    FROM pay_personal_payment_methods_f pppm
                       , pay_org_payment_methods_f_tl popm
                   WHERE pppm.org_payment_method_id =
                                                    popm.org_payment_method_id
                     AND popm.LANGUAGE = 'US'
                     AND pppm.business_group_id = g_business_group_id
                     AND pppm.assignment_id = paaf_assignment_id
                     AND g_cut_off_date BETWEEN pppm.effective_start_date
                                            AND pppm.effective_end_date;
               EXCEPTION
                  WHEN OTHERS
                  THEN
                     pppm_external_account_id := NULL;
                     r_interface_mst.tipo_de_pago := NULL;
                     r_interface_mst.pppm_effective_date := NULL;
               END;

               --fnd_file.put_line (fnd_file.LOG, 'Stage 8');

               IF pppm_external_account_id IS NOT NULL
               THEN
                  BEGIN
                     SELECT pea.segment1 bank_name
                          , pea.segment1 || pea.segment2 bank_branch
                          , pea.segment3 account_number
                          , pea.segment5 control_id
                          , pea.last_update_date bank_update_date
                       INTO r_interface_mst.bank_name
                          , r_interface_mst.bank_branch
                          , r_interface_mst.account_number
                          , r_interface_mst.control_id
                          , r_interface_mst.bank_update_date
                       --FROM hr.pay_external_accounts pea  --code commented by RXNETHI-ARGANO,16/05/23
                       FROM apps.pay_external_accounts pea  --code added by RXNETHI-ARGANO,16/05/23
                      WHERE pea.external_account_id = pppm_external_account_id;
                  EXCEPTION
                     WHEN OTHERS
                     THEN
                        r_interface_mst.bank_name := NULL;
                        r_interface_mst.bank_branch := NULL;
                        r_interface_mst.account_number := NULL;
                        r_interface_mst.control_id := NULL;
                        r_interface_mst.bank_update_date := NULL;
                  END;
               ELSE
                  r_interface_mst.bank_name := NULL;
                  r_interface_mst.bank_branch := NULL;
                  r_interface_mst.account_number := NULL;
                  r_interface_mst.control_id := NULL;
                  r_interface_mst.bank_update_date := NULL;
               END IF;

               --Fnd_File.put_line(Fnd_File.LOG,'Stage 9 papf_person_id ->'||papf_person_id || ' '||);
               cursor_exist := 'NOT EXIST';

               BEGIN
                  FOR r_pcf_data IN c_pcf_data
                  LOOP
                     cursor_exist := 'EXIST';
                     --Fnd_File.put_line(Fnd_File.LOG,'c_pcf_data Fecha_fin_prevista ->'|| r_pcf_data.Fecha_fin_prevista);
                     r_interface_mst.motivo_alta := r_pcf_data.motivo_alta;
                     r_interface_mst.id_contrato_interno :=
                                               r_pcf_data.id_contrato_interno;
                     r_interface_mst.fecha_inicio_cont_específico :=
                                      r_pcf_data.fecha_inicio_cont_específico;
                     r_interface_mst.original_contract_end_date :=
                                        r_pcf_data.original_contract_end_date;
                     r_interface_mst.original_contract_start_date :=
                                      r_pcf_data.original_contract_start_date;
                     r_interface_mst.contract_pps_start_date :=
                                           r_pcf_data.contract_pps_start_date;
                     r_interface_mst.contract_pps_end_date :=
                                             r_pcf_data.contract_pps_end_date;
                     r_interface_mst.contract_active_end_date :=
                                          r_pcf_data.contract_active_end_date;
                     r_interface_mst.fecha_fin_prevista :=
                                                r_pcf_data.fecha_fin_prevista;
                     r_interface_mst.fecha_fin_periodo :=
                                                 r_pcf_data.fecha_fin_periodo;
                     r_interface_mst.fecha_fin_contrato :=
                                                r_pcf_data.fecha_fin_contrato;
                     r_interface_mst.fecha_inicio_bonificacion :=
                                         r_pcf_data.fecha_inicio_bonificacion;
                     r_interface_mst.fecha_fin_bonificacion :=
                                            r_pcf_data.fecha_fin_bonificacion;
                     r_interface_mst.contract_update_date :=
                                              r_pcf_data.contract_update_date;
                                               -- added by C. C. for issue#13
                     --Fnd_File.put_line(Fnd_File.LOG,'c_pcf_data FOUND ->'|| papf_person_id);
                       --Fnd_File.put_line(Fnd_File.LOG,'c_pcf_data Assigned Fecha_fin_prevista ->'||r_interface_mst.Fecha_fin_prevista);
                      --Fnd_File.put_line(Fnd_File.LOG,'Stage 10');
                     get_mst_detail;
-- CCCC
                  END LOOP;                                      -- c_pcf_data
               EXCEPTION
                  WHEN NO_DATA_FOUND
                  THEN
                     r_interface_mst.motivo_alta := NULL;
                     r_interface_mst.id_contrato_interno := NULL;
                     r_interface_mst.fecha_inicio_cont_específico := NULL;
                     r_interface_mst.original_contract_end_date := NULL;
                     r_interface_mst.original_contract_start_date := NULL;
                     r_interface_mst.contract_pps_start_date := NULL;
                     r_interface_mst.contract_pps_end_date := NULL;
                     r_interface_mst.contract_active_end_date := NULL;
                     r_interface_mst.fecha_fin_prevista := NULL;
                     r_interface_mst.fecha_fin_periodo := NULL;
                     r_interface_mst.fecha_fin_contrato := NULL;
                     r_interface_mst.fecha_inicio_bonificacion := NULL;
                     r_interface_mst.fecha_fin_bonificacion := NULL;
                     r_interface_mst.contract_update_date := NULL;
                     --Fnd_File.put_line(Fnd_File.LOG,'c_pcf_data NO_DATA_FOUND ->'|| papf_person_id);
                     get_mst_detail;
                  WHEN OTHERS
                  THEN
                     r_interface_mst.motivo_alta := NULL;
                     r_interface_mst.id_contrato_interno := NULL;
                     r_interface_mst.fecha_inicio_cont_específico := NULL;
                     r_interface_mst.original_contract_end_date := NULL;
                     r_interface_mst.original_contract_start_date := NULL;
                     r_interface_mst.contract_pps_start_date := NULL;
                     r_interface_mst.contract_pps_end_date := NULL;
                     r_interface_mst.contract_active_end_date := NULL;
                     r_interface_mst.fecha_fin_prevista := NULL;
                     r_interface_mst.fecha_fin_periodo := NULL;
                     r_interface_mst.fecha_fin_contrato := NULL;
                     r_interface_mst.fecha_inicio_bonificacion := NULL;
                     r_interface_mst.fecha_fin_bonificacion := NULL;
                     r_interface_mst.contract_update_date := NULL;
                     --Fnd_File.put_line(Fnd_File.LOG,'c_pcf_data OTHERS ->'||  papf_person_id);
                     get_mst_detail;
               END;

               IF cursor_exist = 'NOT EXIST'
               THEN
                  r_interface_mst.motivo_alta := NULL;
                  r_interface_mst.id_contrato_interno := NULL;
                  r_interface_mst.fecha_inicio_cont_específico := NULL;
                  r_interface_mst.original_contract_end_date := NULL;
                  r_interface_mst.original_contract_start_date := NULL;
                  r_interface_mst.fecha_fin_prevista := NULL;
                  r_interface_mst.fecha_fin_periodo := NULL;
                  r_interface_mst.fecha_fin_contrato := NULL;
                  r_interface_mst.fecha_inicio_bonificacion := NULL;
                  r_interface_mst.fecha_fin_bonificacion := NULL;
                  r_interface_mst.contract_update_date := NULL;
                  --Fnd_File.put_line(Fnd_File.LOG,'Stage 11');
                  get_mst_detail;
               END IF;
            END LOOP;                                           -- c_pcak_data
         END LOOP;                                              -- c_paaf_data
      END LOOP;                                                 -- c_papf_data

      COMMIT;
      fnd_file.put_line
         (fnd_file.LOG
        ,    'Finished to populate cust.ttec_spain_pay_interface_MST table - 1st pass...'
          || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS')
         );
      fnd_file.put_line
         (fnd_file.LOG
        ,    'Starting to populate cust.ttec_spain_pay_interface_MST table - 2nd pass...'
          || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS')
         );

-- Ken Mod starting.. 7/23/05 to pull terminated and proccessed on or before todday (v_extract_date).
--AAA
      FOR r_pps_emp_data IN c_pps_emp_data
      LOOP
         v_term_his := NULL;
         v_papf_effective_start_date := NULL;
         v_papf_effective_end_date := NULL;
         v_paaf_assignment_id := NULL;
         v_paaf_effective_start_date := NULL;
         v_paaf_effective_end_date := NULL;
         v_period_of_service_id := NULL;
         v_actual_termination_date := NULL;
         v_final_process_date := NULL;
         v_leaving_reason := NULL;
         v_date_start := NULL;
         record_changed_term_his
            (r_pps_emp_data.person_id
           , v_extract_date
           ,                 -- is sysdate value retrived at program execution
             v_papf_effective_start_date
           , v_papf_effective_end_date
           , v_paaf_assignment_id
           , v_paaf_effective_start_date
           , v_paaf_effective_end_date
           , v_period_of_service_id
           , v_actual_termination_date
           , v_final_process_date
           , v_leaving_reason
           , v_date_start
           , v_term_his
            );

         IF (   v_term_his = 'Y'
             OR v_term_his = 'X')
         THEN
            -- to pull EX_EMP record in cust.ttec_spain_pay_interface_mst table
            -- for term and rehired and final processed on or before today, the above table will have 2 records with same cut_off_date (EMP and EX_EMP)
            -- EMP rec from c_emp_data cursor, EX_EMP rec from c_term_his_emp_data  cursor
              --Fnd_File.put_line(Fnd_File.LOG,'FIND TERM HIS loc=100 person_id=' || r_pps_emp_data.person_id  );         -- delete_later
            FOR r_emp_data IN
               c_term_his_emp_data (r_pps_emp_data.person_id
                                  , v_papf_effective_start_date
                                  , v_papf_effective_end_date
                                  , v_paaf_effective_start_date
                                  , v_paaf_effective_end_date
                                  , v_date_start
                                  , v_paaf_assignment_id
                                   )
            LOOP
-- Ken ??? the following query uses g_cut_off_date now, but it may need to be changed to pull info, it is ok now
-- because termination output does not care of the following info.
               BEGIN
                  SELECT f.screen_entry_value, b.effective_start_date
                    INTO numerossocial, numerossocial_dt
                    FROM pay_element_types_f a
                       , pay_element_entries_f b
                       , pay_input_values_f c
                       , per_all_assignments_f d
                       , per_all_people_f e
                       , pay_element_entry_values_f f
                   WHERE a.element_name =
                                      'Social Security Details'
                                                               --'Tax Details'
                     AND g_cut_off_date BETWEEN a.effective_start_date
                                            AND a.effective_end_date
                     AND g_cut_off_date BETWEEN b.effective_start_date
                                            AND b.effective_end_date
                     AND b.element_type_id = a.element_type_id
                     AND a.element_type_id = c.element_type_id
                     AND g_cut_off_date BETWEEN c.effective_start_date
                                            AND c.effective_end_date
                     AND c.NAME = 'Social Security Identifier'
                     AND b.assignment_id = d.assignment_id
                     AND d.primary_flag = 'Y'
                     AND d.assignment_id = r_emp_data.assignment_id
                     AND b.effective_start_date BETWEEN d.effective_start_date
                                                    AND d.effective_end_date
                     AND e.person_id = d.person_id
                     AND e.employee_number = r_emp_data.oracle_employee_id
                     AND g_cut_off_date BETWEEN e.effective_start_date
                                            AND e.effective_end_date
                     AND g_cut_off_date BETWEEN f.effective_start_date
                                            AND f.effective_end_date
                     AND f.input_value_id = c.input_value_id
                     AND f.element_entry_id = b.element_entry_id;
               EXCEPTION
                  WHEN OTHERS
                  THEN
                     numerossocial := NULL;
                     numerossocial_dt := NULL;
               END;

               BEGIN
                  SELECT f.screen_entry_value, b.effective_start_date
                    INTO idcontratointerno, idcontratointerno_dt
                    FROM pay_element_types_f a
                       , pay_element_entries_f b
                       , pay_input_values_f c
                       , per_all_assignments_f d
                       , per_all_people_f e
                       , pay_element_entry_values_f f
                   WHERE a.element_name =
                                      'Social Security Details'
                                                               --'Tax Details'
                     AND g_cut_off_date BETWEEN a.effective_start_date
                                            AND a.effective_end_date
                     AND g_cut_off_date BETWEEN b.effective_start_date
                                            AND b.effective_end_date
                     AND b.element_type_id = a.element_type_id
                     AND a.element_type_id = c.element_type_id
                     AND g_cut_off_date BETWEEN c.effective_start_date
                                            AND c.effective_end_date
                     AND c.NAME = 'Contract Key'
                     AND b.assignment_id = d.assignment_id
                     AND d.primary_flag = 'Y'
                     AND d.assignment_id = r_emp_data.assignment_id
                     AND b.effective_start_date BETWEEN d.effective_start_date
                                                    AND d.effective_end_date
                     AND e.person_id = d.person_id
                     AND e.employee_number = r_emp_data.oracle_employee_id
                     AND g_cut_off_date BETWEEN e.effective_start_date
                                            AND e.effective_end_date
                     AND g_cut_off_date BETWEEN f.effective_start_date
                                            AND f.effective_end_date
                     AND f.input_value_id = c.input_value_id
                     AND f.element_entry_id = b.element_entry_id;
               EXCEPTION
                  WHEN OTHERS
                  THEN
                     idcontratointerno := NULL;
                     idcontratointerno_dt := NULL;
               END;

               BEGIN
                  SELECT f.screen_entry_value, b.effective_start_date
                    INTO epigrafe, epigrafe_dt
                    FROM pay_element_types_f a
                       , pay_element_entries_f b
                       , pay_input_values_f c
                       , per_all_assignments_f d
                       , per_all_people_f e
                       , pay_element_entry_values_f f
                   WHERE a.element_name =
                                      'Social Security Details'
                                                               --'Tax Details'
                     AND g_cut_off_date BETWEEN a.effective_start_date
                                            AND a.effective_end_date
                     AND g_cut_off_date BETWEEN b.effective_start_date
                                            AND b.effective_end_date
                     AND b.element_type_id = a.element_type_id
                     AND a.element_type_id = c.element_type_id
                     AND g_cut_off_date BETWEEN c.effective_start_date
                                            AND c.effective_end_date
                     AND c.NAME = 'SS Epigraph Code'
                     AND b.assignment_id = d.assignment_id
                     AND d.primary_flag = 'Y'
                     AND d.assignment_id = r_emp_data.assignment_id
                     AND b.effective_start_date BETWEEN d.effective_start_date
                                                    AND d.effective_end_date
                     AND e.person_id = d.person_id
                     AND e.employee_number = r_emp_data.oracle_employee_id
                     AND g_cut_off_date BETWEEN e.effective_start_date
                                            AND e.effective_end_date
                     AND g_cut_off_date BETWEEN f.effective_start_date
                                            AND f.effective_end_date
                     AND f.input_value_id = c.input_value_id
                     AND f.element_entry_id = b.element_entry_id;
               EXCEPTION
                  WHEN OTHERS
                  THEN
                     epigrafe := NULL;
                     epigrafe_dt := NULL;
               END;

               BEGIN
                  SELECT f.screen_entry_value, b.effective_start_date
                    INTO clavepercepcion, clavepercepcion_dt
                    FROM pay_element_types_f a
                       , pay_element_entries_f b
                       , pay_input_values_f c
                       , per_all_assignments_f d
                       , per_all_people_f e
                       , pay_element_entry_values_f f
                   WHERE a.element_name = 'Tax Details'
                     AND g_cut_off_date BETWEEN a.effective_start_date
                                            AND a.effective_end_date
                     AND g_cut_off_date BETWEEN b.effective_start_date
                                            AND b.effective_end_date
                     AND b.element_type_id = a.element_type_id
                     AND a.element_type_id = c.element_type_id
                     AND g_cut_off_date BETWEEN c.effective_start_date
                                            AND c.effective_end_date
                     AND c.NAME = 'Payment Key'
                     AND b.assignment_id = d.assignment_id
                     AND d.primary_flag = 'Y'
                     AND d.assignment_id = r_emp_data.assignment_id
                     AND b.effective_start_date BETWEEN d.effective_start_date
                                                    AND d.effective_end_date
                     AND e.person_id = d.person_id
                     AND e.employee_number = r_emp_data.oracle_employee_id
                     AND g_cut_off_date BETWEEN e.effective_start_date
                                            AND e.effective_end_date
                     AND g_cut_off_date BETWEEN f.effective_start_date
                                            AND f.effective_end_date
                     AND f.input_value_id = c.input_value_id
                     AND f.element_entry_id = b.element_entry_id;
               EXCEPTION
                  WHEN OTHERS
                  THEN
                     clavepercepcion := NULL;
                     clavepercepcion_dt := NULL;
               END;

               r_interface_mst.employee_id := r_emp_data.employee_id;
               r_interface_mst.last_name := r_emp_data.last_name;
               r_interface_mst.second_last_name := r_emp_data.second_last_name;
               r_interface_mst.first_name := r_emp_data.first_name;
               r_interface_mst.birth_date := r_emp_data.birth_date;
               r_interface_mst.gender := r_emp_data.gender;
               r_interface_mst.treatment := r_emp_data.treatment;
               r_interface_mst.nationality := r_emp_data.nationality;
               r_interface_mst.nif_value := r_emp_data.nif_value;
               r_interface_mst.nie := r_emp_data.nie;
               r_interface_mst.numero_s_social := numerossocial;
               r_interface_mst.irpf := r_emp_data.irpf;
               r_interface_mst.id_direccion := r_emp_data.id_direccion;
               r_interface_mst.address_line1 := r_emp_data.address_line1;
               r_interface_mst.address_line2 := r_emp_data.address_line2;
               -- r_interface_mst.country                   := r_emp_data.country;
               r_interface_mst.region_1 := r_emp_data.region_1;
               r_interface_mst.postal_code := r_emp_data.postal_code;
               r_interface_mst.address_line3 := r_emp_data.address_line3;
               r_interface_mst.ordinal_periodo := r_emp_data.ordinal_periodo;
               r_interface_mst.ass_eff_date := r_emp_data.ass_eff_date;
               r_interface_mst.motivo_alta := r_emp_data.motivo_alta;
               r_interface_mst.fecha_antiguedad := r_emp_data.fecha_antiguedad;
               r_interface_mst.fecha_extra := r_emp_data.fecha_extra;
               r_interface_mst.tipo_empleado := r_emp_data.tipo_empleado;
               r_interface_mst.pago_gestiontiempo :=
                                                 r_emp_data.pago_gestiontiempo;
               r_interface_mst.modelo_de_referencia :=
                                               r_emp_data.modelo_de_referencia;
               r_interface_mst.legal_employer := r_emp_data.legal_employer;
               r_interface_mst.id_contrato_interno := idcontratointerno;
               r_interface_mst.fecha_fin_prevista :=
                                                 r_emp_data.fecha_fin_prevista;
               r_interface_mst.fecha_fin_periodo :=
                                                  r_emp_data.fecha_fin_periodo;
               r_interface_mst.fecha_fin_contrato :=
                                                 r_emp_data.fecha_fin_contrato;
               r_interface_mst.clausulas_adicionales :=
                                              r_emp_data.clausulas_adicionales;
               r_interface_mst.condicion_desempleado :=
                                              r_emp_data.condicion_desempleado;
               r_interface_mst.relacion_laboral_especial :=
                                          r_emp_data.relacion_laboral_especial;
               r_interface_mst.causa_sustitucion :=
                                                  r_emp_data.causa_sustitucion;
               r_interface_mst.mujer_subrepresentda :=
                                               r_emp_data.mujer_subrepresentda;
               r_interface_mst.incapacitado_readmitido :=
                                            r_emp_data.incapacitado_readmitido;
               r_interface_mst.primer_trabajador_autonomo :=
                                         r_emp_data.primer_trabajador_autonomo;
               r_interface_mst.exclusion_social := r_emp_data.exclusion_social;
               r_interface_mst.fecha_inicio_cont_específico :=
                                       r_emp_data.fecha_inicio_cont_específico;
               r_interface_mst.fic_especifico := r_emp_data.fic_especifico;
               r_interface_mst.numero_ss_sustituido :=
                                               r_emp_data.numero_ss_sustituido;
               r_interface_mst.renta_active_insercion :=
                                             r_emp_data.renta_active_insercion;
               r_interface_mst.mujer_mater_24_meses :=
                                               r_emp_data.mujer_mater_24_meses;
               r_interface_mst.mantiene_contrato_legal :=
                                            r_emp_data.mantiene_contrato_legal;
               r_interface_mst.contrato_relevo := r_emp_data.contrato_relevo;
               r_interface_mst.mujer_reincorporada :=
                                                r_emp_data.mujer_reincorporada;
               r_interface_mst.excluido_fichero_afi :=
                                               r_emp_data.excluido_fichero_afi;
               r_interface_mst.normal_hours := r_emp_data.normal_hours;
               r_interface_mst.work_center := r_emp_data.work_center;
               r_interface_mst.convenio := r_emp_data.convenio;
               r_interface_mst.epigrafe := epigrafe;
               r_interface_mst.grupo_tarifa := r_emp_data.grupo_tarifa;
               r_interface_mst.clave_percepcion := clavepercepcion;
               r_interface_mst.tax_id := r_emp_data.tax_id;
               r_interface_mst.tipo_salario := r_emp_data.tipo_salario;
               r_interface_mst.tipo_de_ajuste := r_emp_data.tipo_de_ajuste;
               r_interface_mst.job_id := r_emp_data.job_id;
               r_interface_mst.new_job_id := r_emp_data.new_job_id;
               r_interface_mst.departmento := r_emp_data.departmento;
               r_interface_mst.centro_de_trabajo :=
                                                  r_emp_data.centro_de_trabajo;
               r_interface_mst.nivel_salarial := r_emp_data.nivel_salarial;
               r_interface_mst.centros_de_coste := r_emp_data.centros_de_coste;
               r_interface_mst.salary := r_emp_data.salary;
               r_interface_mst.bank_name := r_emp_data.bank_name;
               r_interface_mst.bank_branch := r_emp_data.bank_branch;
               r_interface_mst.account_number := r_emp_data.account_number;
               r_interface_mst.control_id := r_emp_data.control_id;
               r_interface_mst.tipo_de_pago := r_emp_data.tipo_de_pago;
               r_interface_mst.banco_emisor := r_emp_data.banco_emisor;
               r_interface_mst.person_type := r_emp_data.person_type;
               r_interface_mst.date_start := r_emp_data.date_start;
               r_interface_mst.salary_change_date :=
                                                 r_emp_data.salary_change_date;
               r_interface_mst.person_creation_date :=
                                               r_emp_data.person_creation_date;
               r_interface_mst.person_update_date :=
                                                 r_emp_data.person_update_date;
               r_interface_mst.assignment_id := r_emp_data.assignment_id;
               r_interface_mst.assignment_creation_date :=
                                           r_emp_data.assignment_creation_date;
               r_interface_mst.assignment_update_date :=
                                             r_emp_data.assignment_update_date;
               r_interface_mst.payroll_id := r_emp_data.payroll_id;
               r_interface_mst.payroll_name := r_emp_data.payroll_name;
               r_interface_mst.person_id := r_emp_data.person_id;
               r_interface_mst.party_id := r_emp_data.party_id;
               r_interface_mst.person_type_id := r_emp_data.person_type_id;
               r_interface_mst.system_person_type :=
                                                 r_emp_data.system_person_type;
               r_interface_mst.user_person_type := r_emp_data.user_person_type;
               r_interface_mst.period_of_service_id :=
                                               r_emp_data.period_of_service_id;
               r_interface_mst.actual_termination_date :=
                                            r_emp_data.actual_termination_date;
               r_interface_mst.leaving_reason := r_emp_data.leaving_reason;
               r_interface_mst.creation_date := g_cut_off_date;
               r_interface_mst.last_extract_date := SYSDATE;
               r_interface_mst.last_extract_file_type := ' PAYROLL RUN';
               r_interface_mst.cut_off_date := g_cut_off_date;
               r_interface_mst.pppm_effective_date :=
                                                r_emp_data.pppm_effective_date;
               r_interface_mst.address_date_start :=
                                                 r_emp_data.address_date_start;
               r_interface_mst.numerossocial_dt := numerossocial_dt;
               r_interface_mst.idcontratointerno_dt := idcontratointerno_dt;
               r_interface_mst.epigrafe_dt := epigrafe_dt;
               r_interface_mst.clavepercepcion_dt := clavepercepcion_dt;
               r_interface_mst.costsegment_dt := r_emp_data.costsegment_dt;
               r_interface_mst.fecha_inicio_bonificacion :=
                                          r_emp_data.fecha_inicio_bonificacion;
               r_interface_mst.fecha_fin_bonificacion :=
                                             r_emp_data.fecha_fin_bonificacion;
               r_interface_mst.marital_status := r_emp_data.marital_status;
                                      -- WO#131875  added By C.Chan 09/21/2005
               r_interface_mst.telephone1 := r_emp_data.telephone1;
                                       -- WO#144030 added By C.Chan 12/21/2005
               r_interface_mst.telephone2 := r_emp_data.telephone2;
                                       -- WO#144030 added By C.Chan 12/21/2005
               r_interface_mst.notified_termination_date :=
                                          r_emp_data.notified_termination_date;
                                      -- WO#150091  added By C.Chan 12/21/2005
               r_interface_mst.fecha_de_incorporacion :=
                                             r_emp_data.fecha_de_incorporacion;
                                      -- WO#150091  added By C.Chan 12/22/2005
               insert_interface_mst (ir_interface_mst => r_interface_mst);
            END LOOP;                                   -- c_term_his_emp_data
         END IF;
      END LOOP;                                              -- c_pps_emp_data

-- Ken Mod ending.. 7/23/05 to pull terminated and proccessed on or before todday (v_extract_date).
      COMMIT;
      fnd_file.put_line
           (fnd_file.LOG
          ,    'Finished to populate cust.ttec_spain_pay_interface_MST table '
            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS')
           );
   EXCEPTION
      WHEN OTHERS
      THEN
         ROLLBACK;
         g_retcode := SQLCODE;
         g_errbuf := SUBSTR (SQLERRM, 1, 255);
         fnd_file.put_line (fnd_file.LOG, 'Populate Interface Failed');
         fnd_file.put_line (fnd_file.LOG, SUBSTR (SQLERRM, 1, 255));
         RAISE g_e_abort;
   END;                                 -- procedure populate_interface_tables

---============================
   PROCEDURE maintain_interface_tables
   IS
      v_min_date          DATE;
      v_max_date          DATE;
      v_diff_date_count   NUMBER;
      v_date_interval     NUMBER;
   BEGIN
      fnd_file.put_line (fnd_file.LOG
                       , 'Starting to maintain interface tables...'
                        );

      SELECT MAX (cut_off_date) max_date, MIN (cut_off_date) min_date
           , COUNT (DISTINCT cut_off_date) diff_date_count
           , MAX (cut_off_date) - MIN (cut_off_date) date_interval
        INTO v_max_date, v_min_date
           , v_diff_date_count
           , v_date_interval
        --FROM cust.ttec_spain_pay_interface_mst;  --code commented by RXNETHI-ARGANO,16/05/23
        FROM apps.ttec_spain_pay_interface_mst;    --code added by RXNETHI-ARGANO,16/05/23

      IF (    v_diff_date_count > 2
          AND v_date_interval > 2)
      THEN
         fnd_file.put_line (fnd_file.LOG
                          , ' Min Date        -> ' || v_min_date
                           );
         fnd_file.put_line (fnd_file.LOG
                          , ' Max Date        -> ' || v_max_date);
         fnd_file.put_line (fnd_file.LOG
                          , ' Diff Date Count -> ' || v_diff_date_count
                           );
         fnd_file.put_line (fnd_file.LOG
                          , ' Date Interval   -> ' || v_date_interval
                           );
         fnd_file.put_line (fnd_file.LOG
                          ,    ' Deleting data for cut_off_date  -> '
                            || v_min_date
                           );

         --DELETE FROM cust.ttec_spain_pay_interface_mst del  --code commented by RXNETHI-ARGANO,16/05/23
         DELETE FROM apps.ttec_spain_pay_interface_mst del    --code added by RXNETHI-ARGANO,16/05/23
               WHERE TRUNC (del.cut_off_date) = TRUNC (v_min_date);

         --DELETE FROM cust.ttec_spain_pay_interface_pps del  --code commented by RXNETHI-ARGANO,16/05/23
         DELETE FROM apps.ttec_spain_pay_interface_pps del    --code added by RXNETHI-ARGANO,16/05/23
               WHERE TRUNC (del.cut_off_date) = TRUNC (v_min_date);

         COMMIT;
      ELSE
         fnd_file.put_line
                         (fnd_file.LOG
                        , ' No cut_off_date to delete from interface tables '
                         );
         fnd_file.put_line (fnd_file.LOG, ' ');
         fnd_file.put_line (fnd_file.LOG
                          , ' Min Date        -> ' || v_min_date);
         fnd_file.put_line (fnd_file.LOG
                          , ' Max Date        -> ' || v_max_date);
         fnd_file.put_line (fnd_file.LOG
                          , ' Diff Date Count -> ' || v_diff_date_count
                           );
         fnd_file.put_line (fnd_file.LOG
                          , ' Date Interval   -> ' || v_date_interval
                           );
      END IF;

      fnd_file.put_line (fnd_file.LOG
                       , 'Finished to maintain interface tables...'
                        );
   EXCEPTION
      WHEN OTHERS
      THEN
         ROLLBACK;
         g_retcode := SQLCODE;
         g_errbuf := SUBSTR (SQLERRM, 1, 255);
         fnd_file.put_line (fnd_file.LOG, 'Maintain Interface Tables Failed');
         fnd_file.put_line (fnd_file.LOG, SUBSTR (SQLERRM, 1, 255));
         RAISE g_e_abort;
   END;                                 -- procedure maintain_interface_tables

--================================================================================
   PROCEDURE extract_spain_emps (
      ov_errbuf         OUT      VARCHAR2
    , ov_retcode        OUT      NUMBER
    , iv_cut_off_date   IN       VARCHAR2
                           --  Modified by C.Chan on 27-DEC-2005 for TT#411517
   --baseline_indicator IN VARCHAR2
   )                       --  Modified by C.Chan on 01-FEB-2005 for TT#456121
   IS
      l_no_day_to_process           NUMBER;
      l_processing_date             DATE;
      l_skip_baseline_date_output   BOOLEAN := FALSE;
   BEGIN
      --
      /* V 1.0 the following is needed for view to see data */
      INSERT INTO fnd_sessions
           VALUES (USERENV ('SESSIONID'), TRUNC (SYSDATE));
      dbms_session.set_nls('NLS_LANGUAGE','AMERICAN');
      /* V 1.0 end */

      DBMS_SESSION.set_nls ('nls_date_format', '''dd/mm/rrrr''');
      set_business_group_id (iv_business_group => 'TeleTech Holdings - ESP');
      --  Added by C.Chan on 27-DEC-2005 for TT#411517
      fnd_file.put_line (fnd_file.LOG
                       ,    'Business Group ID = '
                         || TO_CHAR (g_business_group_id)
                        );

      IF     iv_cut_off_date IS NOT NULL
         AND TO_DATE (iv_cut_off_date, 'DD-MM-RRRR') <= TRUNC (SYSDATE)
      THEN
         g_cut_off_date := TO_DATE (iv_cut_off_date, 'DD-MM-RRRR');
      ELSE
         RAISE g_e_future_date;
      END IF;

      fnd_file.put_line (fnd_file.LOG
                       ,    'Cut Off Date      = '
                         || TO_CHAR (g_cut_off_date, 'MM/DD/YYYY')
                        );
      g_date_interval := NULL;
      g_max_cut_off_date := NULL;

      BEGIN
         SELECT g_cut_off_date - MAX (cut_off_date), MAX (cut_off_date)
           INTO g_date_interval, g_max_cut_off_date
           --FROM cust.ttec_spain_pay_interface_mst;   --code commented by RXNETHI-ARGANO,16/05/23
           FROM apps.ttec_spain_pay_interface_mst;     --code added by RXNETHI-ARGANO,16/05/23
      EXCEPTION
         WHEN NO_DATA_FOUND
         THEN
            fnd_file.put_line (fnd_file.LOG, 'No data found');
            g_start_cut_off_date := g_cut_off_date - 1;
            l_skip_baseline_date_output := TRUE;
         WHEN OTHERS
         THEN
            fnd_file.put_line
                (fnd_file.LOG
               , 'Process Aborted - Obtain date interval to process Extracts'
                );
            fnd_file.put_line (fnd_file.LOG
                             , SQLCODE || ' - ' || SUBSTR (SQLERRM, 1, 255)
                              );
      END;

      fnd_file.put_line (fnd_file.LOG
                       ,    'g_max_cut_off_date      = '
                         || TO_CHAR (g_max_cut_off_date, 'MM/DD/YYYY')
                        );

      IF    g_date_interval IS NULL
         OR g_date_interval <= -1
      THEN
         fnd_file.put_line
                          (fnd_file.LOG
                         , 'g_date_interval is null or g_date_interval <= -1'
                          );
         g_start_cut_off_date := g_cut_off_date - 1;
         l_skip_baseline_date_output := TRUE;
         l_no_day_to_process := 2;

         --EXECUTE IMMEDIATE ('TRUNCATE TABLE cust.ttec_spain_pay_interface_mst');   --code commented by RXNETHI-ARGANO,16/05/23
         EXECUTE IMMEDIATE ('TRUNCATE TABLE apps.ttec_spain_pay_interface_mst');     --code added by RXNETHI-ARGANO,16/05/23

         --EXECUTE IMMEDIATE ('TRUNCATE TABLE cust.ttec_spain_pay_interface_pps');   --code commented by RXNETHI-ARGANO,16/05/23
         EXECUTE IMMEDIATE ('TRUNCATE TABLE apps.ttec_spain_pay_interface_pps');     --code added by RXNETHI-ARGANO,16/05/23
      ELSIF g_date_interval > 1
      THEN
         fnd_file.put_line (fnd_file.LOG, 'g_date_interval > 1');
         g_start_cut_off_date := g_max_cut_off_date + 1;
         l_no_day_to_process := g_date_interval;
      ELSE                                  --IF g_date_interval in (1,0) THEN
         fnd_file.put_line (fnd_file.LOG
                          , 'Else block: g_date_interval in (1,0) '
                           );
         g_start_cut_off_date := g_cut_off_date;
         l_no_day_to_process := 1;
      END IF;

      g_cut_off_date := g_start_cut_off_date;
      fnd_file.put_line (fnd_file.LOG
                       ,    'g_start_cut_off_date      = '
                         || TO_CHAR (g_start_cut_off_date, 'MM/DD/YYYY')
                        );
      fnd_file.put_line (fnd_file.LOG
                       , 'l_no_day_to_process       = ' || l_no_day_to_process
                        );

      FOR i IN 1 .. l_no_day_to_process
      LOOP
         fnd_file.put_line (fnd_file.LOG
                          ,    'Cut Off Date      = '
                            || TO_CHAR (g_cut_off_date, 'MM/DD/YYYY')
                           );
         fnd_file.put_line (fnd_file.LOG
                          ,    'Starting to populate_interface_tables...'
                            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS')
                           );
         populate_interface_tables;
         fnd_file.put_line (fnd_file.LOG
                          ,    'Finished to populate_interface_tables...'
                            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS')
                           );

--  Print_line
         IF NOT l_skip_baseline_date_output
         THEN
            fnd_file.put_line (fnd_file.LOG
                             ,    'Starting to extract_hires...'
                               || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS')
                              );
            extract_hires;                                             -- NAEN
            fnd_file.put_line (fnd_file.LOG
                             ,    'Finished to extract_hires...'
                               || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS')
                              );
            fnd_file.put_line (fnd_file.LOG
                             ,    'Starting to extract_REhires...'
                               || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS')
                              );
            extract_rehires;                                           -- NAEA
            fnd_file.put_line (fnd_file.LOG
                             ,    'Finished to extract_REhires...'
                               || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS')
                              );
            fnd_file.put_line (fnd_file.LOG
                             ,    'Starting to extract_emp_info_change...'
                               || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS')
                              );
            extract_emp_info_change;                                   --- MDP
            fnd_file.put_line (fnd_file.LOG
                             ,    'Finished to extract_emp_info_change...'
                               || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS')
                              );
            fnd_file.put_line (fnd_file.LOG
                             ,    'Starting to extract_emp_address_change...'
                               || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS')
                              );
            extract_emp_address_change;                                 -- MDD
            fnd_file.put_line (fnd_file.LOG
                             ,    'Finished to extract_emp_address_change...'
                               || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS')
                              );
            fnd_file.put_line
                           (fnd_file.LOG
                          ,    'Starting to extract_emp_assignment1_change...'
                            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS')
                           );
            extract_emp_assignment1_change;                             -- MAP
            fnd_file.put_line
                           (fnd_file.LOG
                          ,    'Finished to extract_emp_assignment1_change...'
                            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS')
                           );
            fnd_file.put_line
                           (fnd_file.LOG
                          ,    'Starting to extract_emp_assignment2_change...'
                            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS')
                           );
            extract_emp_assignment2_change;                             -- MAR
            fnd_file.put_line
                           (fnd_file.LOG
                          ,    'Finished to extract_emp_assignment2_change...'
                            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS')
                           );
            fnd_file.put_line (fnd_file.LOG
                             ,    'Starting to extract_termination...'
                               || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS')
                              );
            extract_termination;                                        -- NBE
            fnd_file.put_line (fnd_file.LOG
                             ,    'Finished to extract_termination...'
                               || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS')
                              );
            fnd_file.put_line (fnd_file.LOG
                             ,    'Starting to extract_emp_bankdata_change...'
                               || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS')
                              );
            extract_emp_bankdata_change;                               --- MDB
            fnd_file.put_line (fnd_file.LOG
                             ,    'Finished to extract_emp_bankdata_change...'
                               || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS')
                              );
            fnd_file.put_line (fnd_file.LOG
                             ,    'Starting to extract_emp_salary_change...'
                               || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS')
                              );
            extract_emp_salary_change;                                 --- MDS
            fnd_file.put_line (fnd_file.LOG
                             ,    'Finished to extract_emp_salary_change...'
                               || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS')
                              );
            fnd_file.put_line (fnd_file.LOG
                             ,    'Starting to maintain_interface_tables...'
                               || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS')
                              );
            maintain_interface_tables;
            fnd_file.put_line (fnd_file.LOG
                             ,    'Finished to maintain_interface_tables...'
                               || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS')
                              );
         END IF;

         l_skip_baseline_date_output := FALSE;
         g_cut_off_date := g_cut_off_date + 1;
      END LOOP;
   EXCEPTION
      WHEN g_e_abort
      THEN
         fnd_file.put_line (fnd_file.LOG
                          , 'Process Aborted - Contact Teletech Help Desk'
                           );
         ov_retcode := g_retcode;
         ov_errbuf := g_errbuf;
      WHEN g_e_future_date
      THEN
         fnd_file.put_line
             (fnd_file.LOG
            , 'Process Aborted - Enter "Cut_off_date" which is not in future'
             );
         ov_retcode := g_retcode;
         ov_errbuf := g_errbuf;
      --dbms_output.put_line('Process Aborted - Enter "Cut_off_date" which is not in future');
      WHEN OTHERS
      THEN
         fnd_file.put_line
                         (fnd_file.LOG
                        , 'When Others Exception - Contact Teltech Help Desk'
                         );
         ov_retcode := SQLCODE;
         ov_errbuf := SUBSTR (SQLERRM, 1, 255);
   END;                                        -- procedure extract_spain_emps

--============================================================
   PROCEDURE extract_emp_address_change
   IS
      CURSOR c_emp
      IS
         SELECT DISTINCT person_id
                    --FROM cust.ttec_spain_pay_interface_mst a    --code commented by RXNETHI-ARGANO,16/05/23
                    FROM apps.ttec_spain_pay_interface_mst a      --code added by RXNETHI-ARGANO,16/05/23
                   WHERE TRUNC (a.cut_off_date) = g_cut_off_date
                     AND (   ttec_spain_pay_interface_pkg.record_changed_v
                                                             ('ADDRESS_LINE1'
                                                            , a.person_id
                                                            , a.assignment_id
                                                            , g_cut_off_date
                                                             ) = 'Y'
                          OR ttec_spain_pay_interface_pkg.record_changed_v
                                                             ('ADDRESS_LINE2'
                                                            , a.person_id
                                                            , a.assignment_id
                                                            , g_cut_off_date
                                                             ) = 'Y'
                          OR ttec_spain_pay_interface_pkg.record_changed_v
                                                             ('COUNTRY'
                                                            , a.person_id
                                                            , a.assignment_id
                                                            , g_cut_off_date
                                                             ) = 'Y'
                          OR ttec_spain_pay_interface_pkg.record_changed_v
                                                             ('REGION_1'
                                                            , a.person_id
                                                            , a.assignment_id
                                                            , g_cut_off_date
                                                             ) = 'Y'
                          OR ttec_spain_pay_interface_pkg.record_changed_v
                                                             ('POSTAL_CODE'
                                                            , a.person_id
                                                            , a.assignment_id
                                                            , g_cut_off_date
                                                             ) = 'Y'
                          OR ttec_spain_pay_interface_pkg.record_changed_v
                                                             ('ADDRESS_LINE3'
                                                            , a.person_id
                                                            , a.assignment_id
                                                            , g_cut_off_date
                                                             ) = 'Y'
                         );

      v_output     VARCHAR2 (4000);
      ov_retcode   NUMBER;
      ov_errbuf    VARCHAR2 (1000);
   BEGIN
      --Print_line(' Employee Address Date Change');
      FOR r_emp IN c_emp
      LOOP
         get_emp_add_change (r_emp.person_id);
      END LOOP;                                                       -- c_loc
   EXCEPTION
      WHEN OTHERS
      THEN
         fnd_file.put_line (fnd_file.LOG
                          , 'Error from Extract_emp_address_change'
                           );
         ov_retcode := SQLCODE;
         ov_errbuf := SUBSTR (SQLERRM, 1, 255);
   END;                                       -- procedure extract_emp_changes

--==============================================
   PROCEDURE extract_emp_info_change
   IS
      l_person_id          NUMBER;

      CURSOR c_emp
      IS
         SELECT DISTINCT tbpim.person_id, tbpim.employee_id
                       , tbpim.assignment_id, tbpim.last_name
                       , tbpim.second_last_name, tbpim.first_name
                       , tbpim.birth_date, tbpim.gender, tbpim.treatment
                       , tbpim.nationality, tbpim.nif_value, tbpim.nie
                       , tbpim.numero_s_social, tbpim.irpf
                       , tbpim.person_update_date
                       , tbpim.disability
                                      -- Added by C. Chan 8/30/2006 WO#217631
                    --FROM cust.ttec_spain_pay_interface_mst tbpim   --code commented by RXNETHI-ARGANO,16/05/23
                    FROM apps.ttec_spain_pay_interface_mst tbpim     --code added by RXNETHI-ARGANO,16/05/23
                   WHERE tbpim.cut_off_date = g_cut_off_date
                     AND tbpim.original_date_of_hire <
                            g_cut_off_date
                     -- Do not pick up new hires contracts, only existing ones
                     AND contract_pps_start_date != g_cut_off_date
                     AND NVL (tbpim.contract_pps_end_date
                            , TO_DATE ('31-12-4712', 'dd-mm-yyyy')
                             ) >= g_cut_off_date
-- and  to_date(tbpim.FECHA_ANTIGUEDAD,'YYYY/MM/DD') != g_cut_off_date
                     AND EXISTS (
                            ((SELECT tbpim1.person_id, tbpim1.ordinal_periodo
                                   , tbpim1.last_name
                                   , tbpim1.second_last_name
                                   , tbpim1.first_name, tbpim1.birth_date
                                   , tbpim1.gender, tbpim1.treatment
                                   , tbpim1.nationality, tbpim1.nif_value
                                   , tbpim1.nie, tbpim1.numero_s_social
                                   , tbpim1.irpf
                                   , tbpim1.disability
                                       -- Added by C. Chan 8/30/2006 WO#217631
                                --FROM cust.ttec_spain_pay_interface_mst tbpim1   --code commented by RXNETHI-ARGANO,16/05/23
                                FROM apps.ttec_spain_pay_interface_mst tbpim1     --code added by RXNETHI-ARGANO,16/05/23
                               WHERE tbpim1.cut_off_date = g_cut_off_date
                                 AND tbpim1.ordinal_periodo =
                                                         tbpim.ordinal_periodo
                                 AND tbpim1.person_id = tbpim.person_id)
                             MINUS
                             (SELECT tbpim2.person_id, tbpim2.ordinal_periodo
                                   , tbpim2.last_name
                                   , tbpim2.second_last_name
                                   , tbpim2.first_name, tbpim2.birth_date
                                   , tbpim2.gender, tbpim2.treatment
                                   , tbpim2.nationality, tbpim2.nif_value
                                   , tbpim2.nie, tbpim2.numero_s_social
                                   , tbpim2.irpf
                                   , tbpim2.disability
                                       -- Added by C. Chan 8/30/2006 WO#217631
                                --FROM cust.ttec_spain_pay_interface_mst tbpim2   --code commented by RXNETHI-ARGANO,16/05/23
                                FROM apps.ttec_spain_pay_interface_mst tbpim2     --code added by RXNETHI-ARGANO,16/05/23
                               WHERE tbpim2.cut_off_date =
                                        (SELECT MAX (tbpim1.cut_off_date)
                                           --FROM cust.ttec_spain_pay_interface_mst tbpim1   --code commented by RXNETHI-ARGANO,16/05/23
                                           FROM apps.ttec_spain_pay_interface_mst tbpim1     --code added by RXNETHI-ARGANO,16/05/23
                                          WHERE tbpim1.person_id =
                                                               tbpim.person_id
                                            AND tbpim1.ordinal_periodo =
                                                         tbpim.ordinal_periodo
                                            AND tbpim1.cut_off_date <
                                                                g_cut_off_date)
                                 AND tbpim2.person_id = tbpim.person_id)));

      CURSOR c_emp_prev_rec
      IS
         SELECT DISTINCT tbpim2.last_name, tbpim2.second_last_name
                       , tbpim2.first_name, tbpim2.birth_date, tbpim2.gender
                       , tbpim2.treatment, tbpim2.nationality
                       , tbpim2.nif_value, tbpim2.nie, tbpim2.numero_s_social
                       , tbpim2.irpf
                       , tbpim2.disability
                                       -- Added by C. Chan 8/30/2006 WO#217631
                    --FROM cust.ttec_spain_pay_interface_mst tbpim2   --code commented by RXNETHI-ARGANO,16/05/23
                    FROM apps.ttec_spain_pay_interface_mst tbpim2     --code added by RXNETHI-ARGANO,16/05/23
                   WHERE tbpim2.cut_off_date =
                            (SELECT MAX (tbpim1.cut_off_date)
                               --FROM cust.ttec_spain_pay_interface_mst tbpim1   --code commented by RXNETHI-ARGANO,16/05/23
                               FROM apps.ttec_spain_pay_interface_mst tbpim1     --code added by RXNETHI-ARGANO,16/05/23
                              WHERE tbpim1.person_id = l_person_id
                                AND tbpim1.cut_off_date < g_cut_off_date)
                     AND tbpim2.ass_eff_date =
                            (SELECT MAX (tbpim1.ass_eff_date)
                               --FROM cust.ttec_spain_pay_interface_mst tbpim1   --code commented by RXNETHI-ARGANO,16/05/23
                               FROM apps.ttec_spain_pay_interface_mst tbpim1     --code added by RXNETHI-ARGANO,16/05/23
                              WHERE tbpim1.person_id = l_person_id
                                AND tbpim1.cut_off_date < g_cut_off_date)
                     AND tbpim2.person_id = l_person_id;

      v_output             VARCHAR2 (4000);
      ov_retcode           NUMBER;
      ov_errbuf            VARCHAR2 (1000);
      v_last_name          VARCHAR2 (1000);
      v_second_last_name   VARCHAR2 (1000);
      v_first_name         VARCHAR2 (1000);
      v_birth_date         VARCHAR2 (1000);
      v_gender             VARCHAR2 (1000);
      v_treatment          VARCHAR2 (1000);
      v_nationality        VARCHAR2 (1000);
      v_nif_value          VARCHAR2 (1000);
      v_nie                VARCHAR2 (1000);
      v_numero_s_social    VARCHAR2 (1000);
      v_irpf               VARCHAR2 (1000);
      v_irpf_dt            VARCHAR2 (1000);
      v_disability         VARCHAR2 (250);
                                       -- Added by C. Chan 8/30/2006 WO#217631
      l_prev_rec_found     VARCHAR2 (3);
      v_tot_info_changed   NUMBER;
   BEGIN
      FOR r_emp IN c_emp
      LOOP
         l_person_id := r_emp.person_id;
         l_prev_rec_found := 'NO';
         fnd_file.put_line (fnd_file.LOG, 'PERSON_ID' || l_person_id);

         FOR r_emp_prev IN c_emp_prev_rec
         LOOP
            BEGIN
               l_prev_rec_found := 'YES';
               v_tot_info_changed := 0;

               IF NVL (r_emp.last_name, 'X') =
                                              NVL (r_emp_prev.last_name, 'X')
               THEN
                  v_last_name := NULL;
               ELSE
                  v_last_name :=
                            pad_data_output ('VARCHAR2', 30, r_emp.last_name);
                  v_tot_info_changed := v_tot_info_changed + 1;
               END IF;

               IF NVL (r_emp.second_last_name, 'X') =
                                        NVL (r_emp_prev.second_last_name, 'X')
               THEN
                  v_second_last_name := NULL;
               ELSE
                  v_second_last_name :=
                     pad_data_output ('VARCHAR2', 30, r_emp.second_last_name);
                  v_tot_info_changed := v_tot_info_changed + 1;
               END IF;

               IF NVL (r_emp.first_name, 'X') =
                                              NVL (r_emp_prev.first_name, 'X')
               THEN
                  v_first_name := NULL;
               ELSE
                  v_first_name :=
                           pad_data_output ('VARCHAR2', 30, r_emp.first_name);
                  v_tot_info_changed := v_tot_info_changed + 1;
               END IF;

               IF r_emp.birth_date = r_emp_prev.birth_date
               THEN
                  v_birth_date := NULL;
               ELSE
                  v_birth_date := TO_CHAR (r_emp.birth_date, 'yyyy-mm-dd');
                  v_tot_info_changed := v_tot_info_changed + 1;
               END IF;

               IF NVL (r_emp.gender, 'X') = NVL (r_emp_prev.gender, 'X')
               THEN
                  v_gender := NULL;
               ELSE
                  v_gender := pad_data_output ('VARCHAR2', 30, r_emp.gender);
                  v_tot_info_changed := v_tot_info_changed + 1;
               END IF;

               IF NVL (r_emp.treatment, 'X') = NVL (r_emp_prev.treatment, 'X')
               THEN
                  v_treatment := NULL;
               ELSE
                  v_treatment :=
                            pad_data_output ('VARCHAR2', 30, r_emp.treatment);
                  v_tot_info_changed := v_tot_info_changed + 1;
               END IF;

               IF NVL (r_emp.nationality, 'X') =
                                             NVL (r_emp_prev.nationality, 'X')
               THEN
                  v_nationality := NULL;
               ELSE
                  v_nationality :=
                          pad_data_output ('VARCHAR2', 30, r_emp.nationality);
                  v_tot_info_changed := v_tot_info_changed + 1;
               END IF;

               IF NVL (r_emp.nif_value, 'X') = NVL (r_emp_prev.nif_value, 'X')
               THEN
                  v_nif_value := NULL;
               ELSE
                  v_nif_value :=
                            pad_data_output ('VARCHAR2', 30, r_emp.nif_value);
                  v_tot_info_changed := v_tot_info_changed + 1;
               END IF;

               IF NVL (r_emp.nie, 'X') = NVL (r_emp_prev.nie, 'X')
               THEN
                  v_nie := NULL;
               ELSE
                  v_nie := pad_data_output ('VARCHAR2', 30, r_emp.nie);
                  v_tot_info_changed := v_tot_info_changed + 1;
               END IF;

               IF NVL (r_emp.numero_s_social, 'X') =
                                         NVL (r_emp_prev.numero_s_social, 'X')
               THEN
                  v_numero_s_social := NULL;
               ELSE
                  v_numero_s_social :=
                      pad_data_output ('VARCHAR2', 30, r_emp.numero_s_social);
                  v_tot_info_changed := v_tot_info_changed + 1;
               END IF;

               IF NVL (r_emp.irpf, 'X') = NVL (r_emp_prev.irpf, 'X')
               THEN
                  v_irpf := NULL;
                  v_irpf_dt := NULL;
               ELSE
                  v_irpf := pad_data_output ('VARCHAR2', 30, r_emp.irpf);
                  v_irpf_dt :=
                     TO_CHAR (TRUNC (r_emp.person_update_date), 'yyyy-mm-dd');
                  v_tot_info_changed := v_tot_info_changed + 1;
               END IF;

               IF NVL (r_emp.disability, 'X') =
                                              NVL (r_emp_prev.disability, 'X')
               THEN
                  v_disability := NULL;
               ELSE
                  v_disability := r_emp.disability;
                  v_tot_info_changed := v_tot_info_changed + 1;
               END IF;

               IF v_tot_info_changed > 0
               THEN
                  v_output :=
                     delimit_text
                        (iv_number_of_fields      => 16
                       , iv_field1                => pad_data_output
                                                                  ('VARCHAR2'
                                                                 , 16
                                                                 , 'MDP'
                                                                  )
                       , iv_field2                => pad_data_output
                                                            ('VARCHAR2'
                                                           , 30
                                                           , r_emp.employee_id
                                                            )
                       , iv_field3                => v_last_name
                       , iv_field4                => v_second_last_name
                       , iv_field5                => v_first_name
                       , iv_field6                => v_birth_date
                       , iv_field7                => v_gender
                       , iv_field8                => v_treatment
                       , iv_field9                => v_nationality
                       , iv_field10               => v_nif_value
                       , iv_field11               => v_nie
                       , iv_field12               => v_numero_s_social
                       , iv_field13               => v_irpf
                       , iv_field14               => v_irpf_dt
                       , iv_field15               => TO_CHAR
                                                        (r_emp.person_update_date
                                                       , 'yyyy-mm-dd'
                                                        )
                       , iv_field16               => v_disability
                                       -- Added by C. Chan 8/30/2006 WO#217631
                        );
                  --DBMS_OUTPUT.PUT_LINE(LENGTH(v_output));
                  print_line (v_output);
               END IF;
            EXCEPTION
               WHEN OTHERS
               THEN
                  fnd_file.put_line
                     (fnd_file.LOG
                    ,    'Error from Extract_emp_info_change getting old data. Employee id ->'
                      || r_emp.employee_id
                     );
                  ov_retcode := SQLCODE;
                  ov_errbuf := SUBSTR (SQLERRM, 1, 255);
                  fnd_file.put_line (fnd_file.LOG, ov_errbuf);
            END;

            l_person_id := NULL;
         END LOOP;                                               -- r_emp_prev

         IF l_prev_rec_found = 'NO'
         THEN
            --Fnd_File.put_line(Fnd_File.LOG,'MDP - Prev Rec Not found'||l_person_id);
            v_output :=
               delimit_text
                  (iv_number_of_fields      => 16
                 , iv_field1                => pad_data_output ('VARCHAR2'
                                                              , 16
                                                              , 'MDP'
                                                               )
                 , iv_field2                => pad_data_output
                                                            ('VARCHAR2'
                                                           , 30
                                                           , r_emp.employee_id
                                                            )
                 , iv_field3                => pad_data_output
                                                              ('VARCHAR2'
                                                             , 30
                                                             , r_emp.last_name
                                                              )
                 , iv_field4                => pad_data_output
                                                       ('VARCHAR2'
                                                      , 30
                                                      , r_emp.second_last_name
                                                       )
                 , iv_field5                => pad_data_output
                                                             ('VARCHAR2'
                                                            , 30
                                                            , r_emp.first_name
                                                             )
                 , iv_field6                => pad_data_output
                                                             ('VARCHAR2'
                                                            , 30
                                                            , r_emp.birth_date
                                                             )
                 , iv_field7                => pad_data_output ('VARCHAR2'
                                                              , 30
                                                              , r_emp.gender
                                                               )
                 , iv_field8                => pad_data_output
                                                              ('VARCHAR2'
                                                             , 30
                                                             , r_emp.treatment
                                                              )
                 , iv_field9                => pad_data_output
                                                            ('VARCHAR2'
                                                           , 30
                                                           , r_emp.nationality
                                                            )
                 , iv_field10               => pad_data_output
                                                              ('VARCHAR2'
                                                             , 30
                                                             , r_emp.nif_value
                                                              )
                 , iv_field11               => pad_data_output ('VARCHAR2'
                                                              , 30
                                                              , r_emp.nie
                                                               )
                 , iv_field12               => pad_data_output
                                                        ('VARCHAR2'
                                                       , 30
                                                       , r_emp.numero_s_social
                                                        )
                 , iv_field13               => pad_data_output ('VARCHAR2'
                                                              , 30
                                                              , r_emp.irpf
                                                               )
                 , iv_field14               => TO_CHAR
                                                  (TRUNC
                                                      (r_emp.person_update_date
                                                      )
                                                 , 'yyyy-mm-dd'
                                                  )
                 , iv_field15               => TO_CHAR
                                                    (r_emp.person_update_date
                                                   , 'yyyy-mm-dd'
                                                    )
                 , iv_field16               => r_emp.disability
                                       -- Added by C. Chan 8/30/2006 WO#217631
                  );
            print_line (v_output);
         END IF;
      END LOOP;                                                       -- r_emp
   EXCEPTION
      WHEN OTHERS
      THEN
         fnd_file.put_line (fnd_file.LOG
                          , 'Error from Extract_emp_info_change'
                           );
         ov_retcode := SQLCODE;
         ov_errbuf := SUBSTR (SQLERRM, 1, 255);
   END;                                   -- procedure extract_emp_info_change

---=============================================
----============================================
   PROCEDURE extract_emp_assignment1_change
   IS
      l_person_id                   NUMBER;
      l_assignment_id               NUMBER;
      l_id_contrato_interno         VARCHAR2 (40 BYTE);
      l_ass_eff_date                DATE;
      l_map_update_date             VARCHAR2 (1000);

      CURSOR c_emp
      IS
         SELECT tbpim.person_id, tbpim.assignment_id, tbpim.employee_id
              , tbpim.fecha_fin_contrato, tbpim.contract_active_end_date
              , tbpim.id_contrato_interno
              , tbpim.fecha_inicio_cont_específico, tbpim.fecha_antiguedad
              , tbpim.tipo_empleado, tbpim.normal_hours, tbpim.work_center
              , tbpim.person_update_date, tbpim.ordinal_periodo
              , tbpim.ass_eff_date, tbpim.convenio, tbpim.epigrafe
              , tbpim.epigrafe_dt, tbpim.grupo_tarifa
              , tbpim.clave_percepcion, tbpim.tax_id, tbpim.date_start
              , tbpim.tipo_salario, tbpim.tipo_de_ajuste
              , tbpim.fecha_fin_prevista, tbpim.fecha_inicio_bonificacion
              , tbpim.fecha_fin_bonificacion
              , tbpim.original_contract_start_date
              , tbpim.original_contract_end_date, tbpim.contract_update_date
              , tbpim.assignment_update_date, tbpim.pps_update_date
           --FROM cust.ttec_spain_pay_interface_mst tbpim   --code commented by RXNETHI-ARGANO,16/05/23
           FROM apps.ttec_spain_pay_interface_mst tbpim     --code added by RXNETHI-ARGANO,16/05/23
          WHERE tbpim.cut_off_date = g_cut_off_date
            AND contract_pps_start_date !=
                                        g_cut_off_date
                                                      -- added by CC 4/14/2006
-- and  to_date(tbpim.FECHA_ANTIGUEDAD,'YYYY/MM/DD') != g_cut_off_date
            AND NVL (tbpim.contract_pps_end_date
                   , TO_DATE ('31-12-4712', 'dd-mm-yyyy')
                    ) >= g_cut_off_date
--    and tbpim.FECHA_INICIO_CONT_ESPECíFICO = g_cut_off_date
--    and tbpim.ass_eff_date != g_cut_off_date -- C.C. 4/10/2006 not to pick up the rehire row again
            AND tbpim.system_person_type = 'EMP'
            AND tbpim.original_date_of_hire <
                   g_cut_off_date
                 -- V1.0  Do not pickup reinstate in MAP record
            AND NOT EXISTS (select 1
                            --from cust.ttec_spain_pay_interface_mst tbpim1   --code commented by RXNETHI-ARGANO,16/05/23
                            from apps.ttec_spain_pay_interface_mst tbpim1     --code added by RXNETHI-ARGANO,16/05/23
                            where tbpim1.PERSON_ID = tbpim.PERSON_ID
                            and   cut_off_date = g_cut_off_date - 1
                            and assignment_status like 'Excedencia%')
                     -- Do not pick up new hires contracts, only existing ones
            AND TO_DATE
                   (NVL (TO_CHAR (TO_DATE (tbpim.original_contract_end_date
                                         , 'YYYY/MM/DD hh24::mi:ss'
                                          )
                                , 'DD-MON-YYYY'
                                 )
                       , TO_CHAR (tbpim.contract_active_end_date + 1
                                , 'DD-MON-YYYY'
                                 )
                        )
                   ) = g_cut_off_date
         UNION
         SELECT tbpim.person_id, tbpim.assignment_id, tbpim.employee_id
              , tbpim.fecha_fin_contrato, tbpim.contract_active_end_date
              , tbpim.id_contrato_interno, tbpim.fecha_inicio_cont_específico
              , tbpim.fecha_antiguedad, tbpim.tipo_empleado
              , tbpim.normal_hours, tbpim.work_center
              , tbpim.person_update_date, tbpim.ordinal_periodo
              , tbpim.ass_eff_date, tbpim.convenio, tbpim.epigrafe
              , tbpim.epigrafe_dt, tbpim.grupo_tarifa, tbpim.clave_percepcion
              , tbpim.tax_id, tbpim.date_start, tbpim.tipo_salario
              , tbpim.tipo_de_ajuste, tbpim.fecha_fin_prevista
              , tbpim.fecha_inicio_bonificacion, tbpim.fecha_fin_bonificacion
              , tbpim.original_contract_start_date
              , tbpim.original_contract_end_date, tbpim.contract_update_date
              , tbpim.assignment_update_date, tbpim.pps_update_date
           --FROM cust.ttec_spain_pay_interface_mst tbpim   --code commented by RXNETHI-ARGANO,16/05/23
           FROM apps.ttec_spain_pay_interface_mst tbpim     --code added by RXNETHI-ARGANO,16/05/23
          WHERE tbpim.cut_off_date = g_cut_off_date
            AND contract_pps_start_date !=
                                        g_cut_off_date
                                                      -- added by CC 4/14/2006
-- and  to_date(tbpim.FECHA_ANTIGUEDAD,'YYYY/MM/DD') != g_cut_off_date
            AND NVL (tbpim.contract_pps_end_date
                   , TO_DATE ('31-12-4712', 'dd-mm-yyyy')
                    ) >= g_cut_off_date
            AND g_cut_off_date BETWEEN tbpim.original_contract_start_date
                                   AND NVL
                                         (tbpim.contract_active_end_date
                                        , TO_DATE ('31-12-4712', 'dd-mm-yyyy')
                                         )              -- added by CC on 4/27
--    and tbpim.FECHA_INICIO_CONT_ESPECíFICO = g_cut_off_date
--    and tbpim.ass_eff_date != g_cut_off_date -- C.C. 4/10/2006 not to pick up the rehire row again
            AND tbpim.system_person_type = 'EMP'
            AND tbpim.original_date_of_hire <
                   g_cut_off_date
                 -- V1.0  Do not pickup reinstate in MAP record
            AND NOT EXISTS (select 1
                            --from cust.ttec_spain_pay_interface_mst tbpim1   --code commented by RXNETHI-ARGANO,16/05/23
                            from apps.ttec_spain_pay_interface_mst tbpim1     --code added by RXNETHI-ARGANO,16/05/23
                            where tbpim1.PERSON_ID = tbpim.PERSON_ID
                            and   cut_off_date = g_cut_off_date - 1
                            and assignment_status like 'Excedencia%')
                     -- Do not pick up new hires contracts, only existing ones
            AND EXISTS (
                   (SELECT tbpim1.employee_id, tbpim1.fecha_fin_contrato
                         , tbpim1.id_contrato_interno
                         --   , tbpim1.FECHA_INICIO_CONT_ESPECíFICO  -- modify by CC on 4/21/06 should not be here
                           ,tbpim1.fecha_antiguedad, tbpim1.tipo_empleado
                         , tbpim1.normal_hours, tbpim1.work_center
                         --   , tbpim1.person_update_date -- modify by CC on 4/21/06 should not be here
                         --   , tbpim1.MODELO_DE_REFERENCIA
                           ,tbpim1.ordinal_periodo
                                                  --   , tbpim1.ass_eff_date  -- modify by CC on 4/21/06 should not be here
                           , tbpim1.convenio, tbpim1.epigrafe
                         --   , tbpim1.EpiGrafe_DT  -- modify by CC on 4/21/06 should not be here
                           ,tbpim1.grupo_tarifa, tbpim1.clave_percepcion
                         , tbpim1.tax_id, tbpim1.date_start
                         , tbpim1.tipo_salario, tbpim1.tipo_de_ajuste
                         , tbpim1.fecha_fin_prevista
                         , tbpim1.fecha_inicio_bonificacion
                         , tbpim1.fecha_fin_bonificacion
                      --  , tbpim1.Original_contract_end_date -- modify by CC on 4/21/06 should not be here
                    --FROM   cust.ttec_spain_pay_interface_mst tbpim1   --code commented by RXNETHI-ARGANO,16/05/23
                    FROM   apps.ttec_spain_pay_interface_mst tbpim1     --code added by RXNETHI-ARGANO,16/05/23
                     WHERE tbpim1.cut_off_date = g_cut_off_date
                       AND tbpim1.id_contrato_interno =
                                                     tbpim.id_contrato_interno
                       AND tbpim1.person_id = tbpim.person_id)
                   MINUS
                   (SELECT tbpim2.employee_id, tbpim2.fecha_fin_contrato
                         , tbpim2.id_contrato_interno
                         --    , tbpim2.FECHA_INICIO_CONT_ESPECíFICO  -- modify by CC on 4/21/06 should not be here
                           ,tbpim2.fecha_antiguedad, tbpim2.tipo_empleado
                         , tbpim2.normal_hours, tbpim2.work_center
                         --    , tbpim2.person_update_date -- modify by CC on 4/21/06 should not be here
                           ,tbpim2.ordinal_periodo
                                                  --    , tbpim2.ass_eff_date
                           , tbpim2.convenio, tbpim2.epigrafe
                         --    , tbpim2.EpiGrafe_DT  -- modify by CC on 4/21/06 should not be here
                           ,tbpim2.grupo_tarifa, tbpim2.clave_percepcion
                         , tbpim2.tax_id, tbpim2.date_start
                         , tbpim2.tipo_salario, tbpim2.tipo_de_ajuste
                         , tbpim2.fecha_fin_prevista
                         , tbpim2.fecha_inicio_bonificacion
                         , tbpim2.fecha_fin_bonificacion
                      --   , tbpim2.Original_contract_end_date -- modify by CC on 4/21/06 should not be here
                    --FROM   cust.ttec_spain_pay_interface_mst tbpim2    --code commented by RXNETHI-ARGANO,16/05/23
                    FROM   apps.ttec_spain_pay_interface_mst tbpim2      --code added by RXNETHI-ARGANO,16/05/23
                     WHERE tbpim2.cut_off_date =
                              (SELECT MAX (tbpim1.cut_off_date)
                                 --FROM cust.ttec_spain_pay_interface_mst tbpim1   --code commented by RXNETHI-ARGANO,16/05/23
                                 FROM apps.ttec_spain_pay_interface_mst tbpim1     --code added by RXNETHI-ARGANO,16/05/23
                                WHERE tbpim1.person_id = tbpim.person_id
                                  AND tbpim1.id_contrato_interno =
                                                     tbpim.id_contrato_interno
                                  AND tbpim1.cut_off_date < g_cut_off_date)
                       AND tbpim2.id_contrato_interno =
                                                     tbpim.id_contrato_interno
                       AND tbpim2.person_id = tbpim.person_id));

/*
  CURSOR c_emp_prev_rec IS
  select DECODE(TO_CHAR(pcf.effective_end_date,'yyyy')
              , '4712' , NULL ,  pcf.effective_end_date)   Fecha_fin_contrato
  ,PCF.reference                  id_contrato_interno
  ,pcf.effective_start_date                                Fecha_inicio_cont_específico
  ,pcf.ctr_information4                                    Fecha_fin_prevista
  ,pcf.attribute1                                          Fecha_Inicio_Bonificacion
  ,pcf.attribute2                                          Fecha_Fin_Bonificacion
    ,SUBSTR(papf.attribute18,1,10)                           fecha_antiguedad
  ,DECODE(papf.attribute16, NULL , 0 , papf.attribute16)   tipo_empleado
  ,papf.ATTRIBUTE21                                        work_center
  ,papf.last_update_date                                   person_update_date
  ,papf.attribute6                ordinal_periodo
  ,papf.attribute10                                        tax_id
  ,paaf.normal_hours                                        normal_hours
  ,paaf.effective_start_date                                ass_eff_date
  ,paaf.ass_attribute7                                      convenio
  ,paaf.ass_attribute6                                      tipo_salario
  ,paaf.ass_attribute8                                      tipo_de_ajuste
  ,pps.date_start                                           date_start
  ,hsck.SEGMENT5                   grupo_tarifa
  ,NULL                           epigrafe
  ,NULL                      clave_percepcion
  FROM hr.per_all_people_f                    papf
     , hr.per_all_assignments_f               paaf
       , hr.per_periods_of_service              pps
       , per_contracts_f                        pcf
     , HR_SOFT_CODING_KEYFLEX                 hsck
  WHERE  papf.business_group_id = 1804
  AND     papf.person_id               = paaf.person_id
  AND     TRUNC(paaf.effective_start_date) BETWEEN papf.effective_start_date AND papf.effective_end_date
  AND     papf.business_group_id       = paaf.business_group_id
  AND     paaf.SOFT_CODING_KEYFLEX_ID  = hsck.SOFT_CODING_KEYFLEX_ID (+)
  AND     papf.person_id               = pps.person_id
  AND     paaf.period_of_service_id    = pps.period_of_service_id
  AND     papf.person_id               = pcf.person_id (+)
  AND     paaf.effective_start_date    = (SELECT    MAX(effective_start_date)
                                             FROM     per_assignments_f
                                          WHERE    assignment_id = paaf.assignment_id
                                          AND    person_id = papf.person_id                  -- mod by Ken
                                    AND      effective_start_date < TRUNC(to_date('30-JAN-2006')))
  AND  (    (TRUNC( paaf.effective_start_date) BETWEEN pcf.effective_start_date AND pcf.effective_end_date)
       OR (pcf.effective_start_date is null)   )
  and paaf.person_id = l_person_id
  and PCF.reference = l_ID_CONTRATO_INTERNO
  and paaf.assignment_id = l_assignment_id;
 */
      CURSOR c_emp_prev_rec
      IS
         SELECT tbpim2.fecha_fin_contrato, tbpim2.contract_active_end_date
              , tbpim2.id_contrato_interno
              , tbpim2.fecha_inicio_cont_específico
              , tbpim2.fecha_fin_prevista, tbpim2.fecha_inicio_bonificacion
              , tbpim2.fecha_fin_bonificacion, tbpim2.fecha_antiguedad
              , tbpim2.tipo_empleado, tbpim2.work_center
              , tbpim2.person_update_date, tbpim2.ordinal_periodo
              , tbpim2.tax_id, tbpim2.normal_hours, tbpim2.ass_eff_date
              , tbpim2.convenio, tbpim2.tipo_salario, tbpim2.tipo_de_ajuste
              , tbpim2.date_start, tbpim2.grupo_tarifa, tbpim2.epigrafe
              , tbpim2.clave_percepcion, tbpim2.original_contract_end_date
           --FROM cust.ttec_spain_pay_interface_mst tbpim2    --code commented by RXNETHI-ARGANO,16/05/23
           FROM apps.ttec_spain_pay_interface_mst tbpim2      --code added by RXNETHI-ARGANO,16/05/23
          WHERE tbpim2.cut_off_date =
                   (SELECT MAX (tbpim1.cut_off_date)
                      --FROM cust.ttec_spain_pay_interface_mst tbpim1   --code commented by RXNETHI-ARGANO,16/05/23
                      FROM apps.ttec_spain_pay_interface_mst tbpim1     --code added by RXNETHI-ARGANO,16/05/23
                     WHERE tbpim1.person_id = l_person_id
                       -- and   tbpim1.assignment_id       = l_assignment_id
                       AND tbpim1.id_contrato_interno = l_id_contrato_interno
                       AND tbpim1.cut_off_date < g_cut_off_date)
            AND tbpim2.ass_eff_date =
                   (SELECT MAX (tbpim1.ass_eff_date)
                      --FROM cust.ttec_spain_pay_interface_mst tbpim1   --code commented by RXNETHI-ARGANO,16/05/23
                      FROM apps.ttec_spain_pay_interface_mst tbpim1     --code added by RXNETHI-ARGANO,16/05/23
                     WHERE tbpim1.person_id = l_person_id
                       -- and   tbpim1.assignment_id       = l_assignment_id
                       AND tbpim1.id_contrato_interno = l_id_contrato_interno
                       AND tbpim1.cut_off_date < g_cut_off_date)
            AND tbpim2.id_contrato_interno = l_id_contrato_interno
            --and   tbpim2.assignment_id       = l_assignment_id
            AND tbpim2.person_id = l_person_id;

      v_output                      VARCHAR2 (4000);
      ov_retcode                    NUMBER;
      ov_errbuf                     VARCHAR2 (1000);
      v_fecha_antiguedad            VARCHAR2 (45 BYTE);
      v_tipo_empleado               VARCHAR2 (45 BYTE);
      v_normal_hours                NUMBER;
      v_normal_hours_dt             VARCHAR2 (45 BYTE);
      v_papf_eff_dt                 VARCHAR2 (45 BYTE);
      v_work_center                 VARCHAR2 (45 BYTE);
      v_paaf_eff_dt                 VARCHAR2 (45 BYTE);
      v_id_contrato_interno         VARCHAR2 (45 BYTE);
      v_fecha_inicio_contrato       VARCHAR2 (45 BYTE);
      v_convenio                    VARCHAR2 (45 BYTE);
      v_epigrafe                    VARCHAR2 (45 BYTE);
      v_epigrafe_dt                 VARCHAR2 (45 BYTE);
      v_grupo_tarifa                VARCHAR2 (45 BYTE);
      v_grupo_tarifa_dt             VARCHAR2 (45 BYTE);
      v_clave_percepcion            VARCHAR2 (45 BYTE);
      v_clave_percepcion_dt         VARCHAR2 (45 BYTE);
      v_tax_id                      VARCHAR2 (45 BYTE);
      v_date_start                  VARCHAR2 (45 BYTE);
      v_tipo_salario                VARCHAR2 (45 BYTE);
      v_tipo_eff_dt                 VARCHAR2 (45 BYTE);
      v_tipo_de_ajuste              VARCHAR2 (45 BYTE);
      v_fecha_inicio_cont_esp       VARCHAR2 (45 BYTE);
      v_fecha_inicio_cont_esp2      VARCHAR2 (45 BYTE);
      v_fecha_fin_contrato          VARCHAR2 (45 BYTE);
      v_fecha_fin_contrato2         VARCHAR2 (45 BYTE);
      v_fecha_fin_prevista          VARCHAR2 (45 BYTE);
      v_fecha_inicio_bonificacion   VARCHAR2 (45 BYTE);
      v_fecha_fin_bonificacion      VARCHAR2 (45 BYTE);
      v_fecha_fin_prorroga          VARCHAR2 (45 BYTE);
      v_fecha_inicio_prorroga       VARCHAR2 (45 BYTE);
      l_prev_rec_found              VARCHAR2 (3);
      l_insert_first_map_row        VARCHAR2 (3);
      l_insert_second_map_row       VARCHAR2 (3);
      v_tot_info_changed            NUMBER;
   BEGIN
      FOR r_emp IN c_emp
      LOOP
         l_person_id := r_emp.person_id;
         l_assignment_id := r_emp.assignment_id;
         l_ass_eff_date := r_emp.ass_eff_date;
         l_id_contrato_interno := r_emp.id_contrato_interno;
         l_prev_rec_found := 'NO';
         l_insert_first_map_row := 'NO';
         l_insert_second_map_row := 'NO';

         FOR r_emp_prev IN c_emp_prev_rec
         LOOP
            BEGIN
               l_insert_first_map_row := 'NO';
               l_insert_second_map_row := 'NO';
               l_prev_rec_found := 'YES';
               v_tot_info_changed := 0;

  --Fnd_File.put_line(Fnd_File.LOG,'Stage 1');
  --Fnd_File.put_line(Fnd_File.LOG,'1 - record change_count'||v_tot_info_changed);
        -- WO#147293 When a contract extension has to be informed, two consecutive MAP records should be informed
   --  1. Contractact finishing
   --     must have the following info:  Field # 1 Movement Type -> 'MAP''
   --                                    Field # 2 Employee ID
   --                                    Field # 3 Ordinal Period
   --                                    Field # 9 Contract Start Date
   --                                    Field #13 Contract End Date
   --                                    The rest of the fields should be blank
   --
   --Fnd_File.put_line(Fnd_File.LOG,'FECHA_FIN_CONTRATO->'||r_emp.FECHA_FIN_CONTRATO ||'g_cut_off_date->'||g_cut_off_date);
--    IF r_emp.FECHA_FIN_CONTRATO is not NULL
--     THEN
--       V_FECHA_FIN_CONTRATO     := TO_CHAR(r_emp.FECHA_FIN_CONTRATO ,'yyyy-mm-dd');
--    ELSE
--       V_FECHA_FIN_CONTRATO     := NULL;
--    END IF;
--Fnd_File.put_line(Fnd_File.LOG,'2 - record change_count'||v_tot_info_changed);
   --IF r_emp.FECHA_FIN_CONTRATO = g_cut_off_date THEN -- CC on 4/17/2006
               IF TO_DATE
                     (NVL
                         (TO_CHAR (TO_DATE (r_emp.original_contract_end_date
                                          , 'YYYY/MM/DD hh24::mi:ss'
                                           )
                                 , 'DD-MON-YYYY'
                                  )
                        , TO_CHAR (r_emp.contract_active_end_date + 1
                                 , 'DD-MON-YYYY'
                                  )
                         )
                     ) = g_cut_off_date
               THEN
                  l_insert_first_map_row := 'YES';
                  --Fnd_File.put_line(Fnd_File.LOG,'Stage 1.3.2');
                  --V_FECHA_FIN_CONTRATO2 := to_char(TO_DATE(NVL(TO_CHAR(to_date(r_emp.Original_contract_end_date,'YYYY/MM/DD hh24::mi:ss'),'DD-MON-YYYY'),TO_CHAR(r_emp.FECHA_FIN_CONTRATO ,'DD-MON-YYYY'))),'YYYY-MM-DD');
                  v_fecha_fin_contrato2 :=
                     TO_CHAR
                        (TO_DATE
                            (NVL
                                (TO_CHAR
                                    (TO_DATE
                                            (r_emp.original_contract_end_date
                                           , 'YYYY/MM/DD hh24::mi:ss'
                                            )
                                   , 'DD-MON-YYYY'
                                    )
                               , TO_CHAR (r_emp.contract_active_end_date + 1
                                        , 'DD-MON-YYYY'
                                         )
                                )
                            )
                       , 'YYYY-MM-DD'
                        );

                  --Fnd_File.put_line(Fnd_File.LOG,'FECHA FIN Contrato '|| V_FECHA_FIN_CONTRATO2);
                  IF r_emp.original_contract_start_date IS NOT NULL
                  THEN
                     v_fecha_inicio_cont_esp2 :=
                        TO_CHAR (r_emp.original_contract_start_date
                               , 'yyyy-mm-dd'
                                );
                     l_map_update_date :=
                            TO_CHAR (r_emp.contract_update_date, 'yyyy-mm-dd');
                  --Fnd_File.put_line(Fnd_File.LOG,'Stage 1.3.3');
                  ELSE
                     v_fecha_inicio_cont_esp2 := NULL;
                  END IF;
               ELSE
                  IF r_emp.fecha_fin_contrato = r_emp_prev.fecha_fin_contrato
                  THEN                                 --'FECHA_FIN_CONTRATO'
                     v_fecha_fin_contrato := NULL;
                  ELSE
                     IF r_emp.fecha_fin_contrato IS NOT NULL
                     THEN
                        v_fecha_fin_contrato :=
                             TO_CHAR (r_emp.fecha_fin_contrato, 'yyyy-mm-dd');
                        l_map_update_date :=
                           TO_CHAR (r_emp.contract_update_date, 'yyyy-mm-dd');
                     ELSE
                        v_fecha_fin_contrato := NULL;
                     END IF;
                  END IF;
               END IF;

               --Fnd_File.put_line(Fnd_File.LOG,'3 - record change_count'||v_tot_info_changed);
                --  2. Contract Extension
                --     must have the following info:  Field # 1 Movement Type -> 'MAP''
                --                                    Field # 2 Employee ID
                --                                    Field # 3 Ordinal Period
                --                                    Field # 9 Contract Start Date
                --                                    Field #13 Contract End Date
                --                                    Field #48 Contract Extention Start Date
                --                                    Field #49 Contract Extention End Date
                --                                    The rest of the fields should be blank
                --
               --Fnd_File.put_line(Fnd_File.LOG,'Stage 1.3');
               IF (    TO_CHAR (TO_DATE (NVL (r_emp.fecha_fin_prevista
                                            , '4712/12/31 00:00:00'
                                             )
                                       , 'YYYY/MM/DD hh24::mi:ss'
                                        )
                              , 'yyyy-mm-dd'
                               ) =
                          TO_CHAR
                               (TO_DATE (NVL (r_emp_prev.fecha_fin_prevista
                                            , '4712/12/31 00:00:00'
                                             )
                                       , 'YYYY/MM/DD hh24::mi:ss'
                                        )
                              , 'yyyy-mm-dd'
                               )
                   AND r_emp.original_contract_end_date =
                                         r_emp_prev.original_contract_end_date
                  )
               THEN
                  v_fecha_inicio_prorroga := NULL;
                  v_fecha_fin_prorroga := NULL;

                  IF l_insert_first_map_row = 'NO'
                  THEN
                     v_fecha_inicio_cont_esp2 := NULL;
                     v_fecha_fin_contrato2 := NULL;
                  END IF;
               ELSE
                  IF     r_emp.fecha_fin_prevista IS NOT NULL
                     AND r_emp.original_contract_end_date IS NOT NULL
                  THEN
                     --Fnd_File.put_line(Fnd_File.LOG,'Stage 1.3.2');
                     IF TO_NUMBER
                           (pad_data_output
                                 ('VARCHAR2'
                                , 30
                                , TO_CHAR (TO_DATE (r_emp.fecha_fin_prevista
                                                  , 'YYYY/MM/DD hh24::mi:ss'
                                                   )
                                         , 'yyyymmdd'
                                          )
                                 )
                           ) >
                           TO_NUMBER
                              (pad_data_output
                                  ('VARCHAR2'
                                 , 30
                                 , TO_CHAR
                                      (TO_DATE
                                            (r_emp.original_contract_end_date
                                           , 'YYYY/MM/DD hh24::mi:ss'
                                            )
                                     , 'yyyymmdd'
                                      )
                                  )
                              )
                     THEN
                        l_insert_first_map_row := 'YES';
                        --Fnd_File.put_line(Fnd_File.LOG,'Stage 1.3.2.1');
                        v_fecha_fin_contrato2 :=
                           pad_data_output
                              ('VARCHAR2'
                             , 30
                             , TO_CHAR
                                  (TO_DATE (r_emp.original_contract_end_date
                                          , 'YYYY/MM/DD hh24::mi:ss'
                                           )
                                 , 'yyyy-mm-dd'
                                  )
                              );

                        IF r_emp.original_contract_start_date IS NOT NULL
                        THEN
                           --Fnd_File.put_line(Fnd_File.LOG,'Stage 1.3.2.3');
                           v_fecha_inicio_cont_esp2 :=
                              TO_CHAR (r_emp.original_contract_start_date
                                     , 'yyyy-mm-dd'
                                      );
                        ELSE
                           v_fecha_inicio_cont_esp2 := NULL;
                        END IF;

                         --Fnd_File.put_line(Fnd_File.LOG,'FECHA_INICIO_CONT_ESP   ->'||V_FECHA_INICIO_CONT_ESP );
                         --Fnd_File.put_line(Fnd_File.LOG,'FECHA_FIN_CONTRATO      ->'||V_FECHA_FIN_CONTRATO);
                         --Fnd_File.put_line(Fnd_File.LOG,'l_insert_first_MAP_row  ->'||l_insert_first_MAP_row);
                        --Fnd_File.put_line(Fnd_File.LOG,'Stage 1.3.2.4');
                        v_fecha_inicio_prorroga :=
                           TO_CHAR
                                ((  TO_DATE (r_emp.original_contract_end_date
                                           , 'YYYY/MM/DD hh24::mi:ss'
                                            )
                                  + 1
                                 )
                               , 'yyyy-mm-dd'
                                );
                        v_fecha_fin_prorroga :=
                           pad_data_output
                                 ('VARCHAR2'
                                , 30
                                , TO_CHAR (TO_DATE (r_emp.fecha_fin_prevista
                                                  , 'YYYY/MM/DD hh24::mi:ss'
                                                   )
                                         , 'yyyy-mm-dd'
                                          )
                                 );
                        l_insert_second_map_row := 'YES';
                        l_map_update_date :=
                            TO_CHAR (r_emp.contract_update_date, 'yyyy-mm-dd');
                     --Fnd_File.put_line(Fnd_File.LOG,'l_insert_second_MAP_row ->'||l_insert_second_MAP_row);
                     --Fnd_File.put_line(Fnd_File.LOG,'V_FECHA_INICIO_PRORROGA ->'||V_FECHA_INICIO_PRORROGA);
                     --Fnd_File.put_line(Fnd_File.LOG,'V_FECHA_FIN_PRORROGA    ->'||V_FECHA_FIN_PRORROGA );
                     ELSE
                        v_fecha_inicio_prorroga := NULL;
                        v_fecha_fin_prorroga := NULL;

                        IF l_insert_first_map_row = 'NO'
                        THEN
                           v_fecha_inicio_cont_esp2 := NULL;
                           v_fecha_fin_contrato2 := NULL;
                        END IF;
                     END IF;
                  ELSE
                     v_fecha_inicio_prorroga := NULL;
                     v_fecha_fin_prorroga := NULL;

                     IF l_insert_first_map_row = 'NO'
                     THEN
                        v_fecha_inicio_cont_esp2 := NULL;
                        v_fecha_fin_contrato2 := NULL;
                     END IF;
                  END IF;
               END IF;

               --Fnd_File.put_line(Fnd_File.LOG,'Stage 2');
               IF l_insert_first_map_row = 'NO'
               THEN
                  IF r_emp.fecha_antiguedad = r_emp_prev.fecha_antiguedad
                  THEN
                     v_fecha_antiguedad := NULL;
                  ELSE
                     v_fecha_antiguedad :=
                                   REPLACE (r_emp.fecha_antiguedad, '/', '-');
                     l_map_update_date :=
                             TO_CHAR (r_emp.person_update_date, 'yyyy-mm-dd');
                     v_tot_info_changed := v_tot_info_changed + 1;
                  -- Fnd_File.put_line(Fnd_File.LOG,'FECHA_ANTIGUEDAD');
                  END IF;

                  --Fnd_File.put_line(Fnd_File.LOG,'Stage 3');
                  IF NVL (r_emp.tipo_empleado, 'X') =
                                           NVL (r_emp_prev.tipo_empleado, 'X')
                  THEN
                     v_tipo_empleado := '0';
                  ELSE
                     v_tipo_empleado :=
                        pad_data_output ('VARCHAR2', 30, r_emp.tipo_empleado);
                     l_map_update_date :=
                             TO_CHAR (r_emp.person_update_date, 'yyyy-mm-dd');
                     v_tot_info_changed := v_tot_info_changed + 1;
                     fnd_file.put_line (fnd_file.LOG, 'TIPO_EMPLEADO');
                  END IF;

                  --Fnd_File.put_line(Fnd_File.LOG,'Stage 4');
                  IF NVL (r_emp.normal_hours, -99) =
                                             NVL (r_emp_prev.normal_hours
                                                , -99)
                  THEN
                     v_normal_hours := NULL;
                     v_normal_hours_dt := NULL;
                  ELSE
                     v_normal_hours := r_emp.normal_hours;
                     v_normal_hours_dt :=
                           TO_CHAR (TRUNC (r_emp.ass_eff_date), 'yyyy-mm-dd');
                     l_map_update_date :=
                         TO_CHAR (r_emp.assignment_update_date, 'yyyy-mm-dd');
                     v_tot_info_changed := v_tot_info_changed + 1;
                     fnd_file.put_line (fnd_file.LOG, 'NORMAL_HOURS');
                  END IF;

--Fnd_File.put_line(Fnd_File.LOG,'Stage 5');
                  IF NVL (r_emp.work_center, 'X') =
                                             NVL (r_emp_prev.work_center, 'X')
                  THEN
                     v_work_center := NULL;
                     v_papf_eff_dt := NULL;
                  ELSE
                     v_work_center :=
                          pad_data_output ('VARCHAR2', 30, r_emp.work_center);
                     v_papf_eff_dt :=
                        TO_CHAR (TRUNC (r_emp.person_update_date)
                               , 'yyyy-mm-dd'
                                );
                     l_map_update_date :=
                              TO_CHAR (r_emp.person_update_date, 'yyyy-mm-dd');
                     v_tot_info_changed := v_tot_info_changed + 1;
                  --Fnd_File.put_line(Fnd_File.LOG,'WORK_CENTER');
                  END IF;

--Fnd_File.put_line(Fnd_File.LOG,'Stage 6');
                  IF NVL (r_emp.id_contrato_interno, 'X') =
                                     NVL (r_emp_prev.id_contrato_interno, 'X')
                  THEN
--   V_ID_CONTRATO_INTERNO := NULL;
--   V_FECHA_INICIO_CONTRATO := NULL;
                     v_fecha_inicio_cont_esp :=
                        TO_CHAR (r_emp.fecha_inicio_cont_específico
                               , 'yyyy-mm-dd'
                                );
                     v_id_contrato_interno :=
                        pad_data_output ('VARCHAR2'
                                       , 30
                                       , r_emp.id_contrato_interno
                                        );
                     v_fecha_inicio_contrato :=
                            TO_CHAR (TRUNC (r_emp.ass_eff_date), 'yyyy-mm-dd');
                  ELSE
                     v_id_contrato_interno :=
                        pad_data_output ('VARCHAR2'
                                       , 30
                                       , r_emp.id_contrato_interno
                                        );
                     v_fecha_inicio_cont_esp :=
                        TO_CHAR (r_emp.fecha_inicio_cont_específico
                               , 'yyyy-mm-dd'
                                );
                     v_fecha_inicio_contrato :=
                            TO_CHAR (TRUNC (r_emp.ass_eff_date), 'yyyy-mm-dd');
                     l_map_update_date :=
                          TO_CHAR (r_emp.assignment_update_date, 'yyyy-mm-dd');
                     v_tot_info_changed := v_tot_info_changed + 1;
                  --Fnd_File.put_line(Fnd_File.LOG,'MODELO_DE_REF');
                  END IF;

--Fnd_File.put_line(Fnd_File.LOG,'Stage 7');
                  IF NVL (r_emp.convenio, 'X') =
                                                NVL (r_emp_prev.convenio, 'X')
                  THEN
                     v_convenio := NULL;
                     v_paaf_eff_dt := NULL;
                  ELSE
                     v_convenio :=
                             pad_data_output ('VARCHAR2', 30, r_emp.convenio);
                     v_paaf_eff_dt :=
                           TO_CHAR (TRUNC (r_emp.ass_eff_date), 'yyyy-mm-dd');
                     l_map_update_date :=
                         TO_CHAR (r_emp.assignment_update_date, 'yyyy-mm-dd');
                     v_tot_info_changed := v_tot_info_changed + 1;
                     fnd_file.put_line (fnd_file.LOG, 'CONVENIO');
                  END IF;

--Fnd_File.put_line(Fnd_File.LOG,'Stage 8');
                  IF NVL (r_emp.epigrafe, 'X') =
                                                NVL (r_emp_prev.epigrafe, 'X')
                  THEN
                     v_epigrafe := NULL;
                     v_epigrafe_dt := NULL;
                  ELSE
                     v_epigrafe :=
                             pad_data_output ('VARCHAR2', 30, r_emp.epigrafe);
                     v_epigrafe_dt :=
                            TO_CHAR (TRUNC (r_emp.epigrafe_dt), 'yyyy-mm-dd');
                     l_map_update_date :=
                         TO_CHAR (r_emp.assignment_update_date, 'yyyy-mm-dd');
                     v_tot_info_changed := v_tot_info_changed + 1;
                  --Fnd_File.put_line(Fnd_File.LOG,'EPIGRAFE');
                  END IF;

--Fnd_File.put_line(Fnd_File.LOG,'Stage 9');
                  IF NVL (r_emp.grupo_tarifa, 'X') =
                                            NVL (r_emp_prev.grupo_tarifa, 'X')
                  THEN
                     v_grupo_tarifa := NULL;
                     v_grupo_tarifa_dt := NULL;
                  ELSE
                     v_grupo_tarifa :=
                         pad_data_output ('VARCHAR2', 30, r_emp.grupo_tarifa);
                     v_grupo_tarifa_dt :=
                           TO_CHAR (TRUNC (r_emp.ass_eff_date), 'yyyy-mm-dd');
                     l_map_update_date :=
                         TO_CHAR (r_emp.assignment_update_date, 'yyyy-mm-dd');
                     v_tot_info_changed := v_tot_info_changed + 1;
                     fnd_file.put_line (fnd_file.LOG, 'GRUPO_TARIFA');
                  END IF;

--Fnd_File.put_line(Fnd_File.LOG,'Stage 10');
                  IF NVL (r_emp.clave_percepcion, 'X') =
                                        NVL (r_emp_prev.clave_percepcion, 'X')
                  THEN      -- modified by C. Chan on 07/06/2006 for WO#200196
                     v_clave_percepcion := NULL;
                     v_clave_percepcion_dt := NULL;
                                           -- Added by C. Chan for  WO#256205
                  ELSE
                     v_clave_percepcion :=
                        pad_data_output ('VARCHAR2'
                                       , 30
                                       , r_emp.clave_percepcion
                                        );
                     v_clave_percepcion_dt :=
                        TO_CHAR (TRUNC (r_emp.person_update_date)
                               , 'yyyy-mm-dd'
                                );
                     l_map_update_date :=
                              TO_CHAR (r_emp.person_update_date, 'yyyy-mm-dd');
                     v_tot_info_changed := v_tot_info_changed + 1;
                     fnd_file.put_line (fnd_file.LOG, 'CLAVE_PERCEPCION');
                  END IF;

--Fnd_File.put_line(Fnd_File.LOG,'Stage 11');
                  IF NVL (r_emp.tax_id, 'X') = NVL (r_emp_prev.tax_id, 'X')
                  THEN
                     v_tax_id := NULL;
                  ELSE
                     v_tax_id :=
                               pad_data_output ('VARCHAR2', 30, r_emp.tax_id);
                     l_map_update_date :=
                             TO_CHAR (r_emp.person_update_date, 'yyyy-mm-dd');
                     v_tot_info_changed := v_tot_info_changed + 1;
                  --Fnd_File.put_line(Fnd_File.LOG,'TAX_ID');
                  END IF;

--Fnd_File.put_line(Fnd_File.LOG,'Stage 12');
                  IF r_emp.date_start = r_emp_prev.date_start
                  THEN
                     v_date_start := NULL;
                  ELSE
                     v_date_start := TO_CHAR (r_emp.date_start, 'dd-mm-yyyy');
                     l_map_update_date :=
                                TO_CHAR (r_emp.pps_update_date, 'yyyy-mm-dd');
                     v_tot_info_changed := v_tot_info_changed + 1;
                     fnd_file.put_line (fnd_file.LOG, 'DATE_START');
                  END IF;

--Fnd_File.put_line(Fnd_File.LOG,'Stage 13');
                  IF NVL (r_emp.tipo_salario, 'X') =
                                            NVL (r_emp_prev.tipo_salario, 'X')
                  THEN
                     v_tipo_salario := NULL;
                  ELSE
                     v_tipo_salario :=
                         pad_data_output ('VARCHAR2', 30, r_emp.tipo_salario);
                     v_tot_info_changed := v_tot_info_changed + 1;
                     l_map_update_date :=
                         TO_CHAR (r_emp.assignment_update_date, 'yyyy-mm-dd');
                  --Fnd_File.put_line(Fnd_File.LOG,'TIPO_SALARIO');
                  END IF;

--Fnd_File.put_line(Fnd_File.LOG,'Stage 14');
                  IF NVL (r_emp.tipo_de_ajuste, 'X') =
                                          NVL (r_emp_prev.tipo_de_ajuste, 'X')
                  THEN
                     v_tipo_de_ajuste := NULL;
                     v_tipo_eff_dt := NULL;
                  ELSE
                     v_tipo_de_ajuste :=
                        pad_data_output ('VARCHAR2', 30
                                       , r_emp.tipo_de_ajuste);
                      -- Modified by CC on 4/20/2006 TIPO_DE_AJUSTE if from assignment table not people, error in Spec Doc.
                     --V_TIPO_EFF_DT :=  TO_CHAR(TRUNC(r_emp.person_update_date),'yyyy-mm-dd') ;
                     v_tipo_eff_dt :=
                           TO_CHAR (TRUNC (r_emp.ass_eff_date), 'yyyy-mm-dd');
                     l_map_update_date :=
                         TO_CHAR (r_emp.assignment_update_date, 'yyyy-mm-dd');
                     v_tot_info_changed := v_tot_info_changed + 1;
                     fnd_file.put_line (fnd_file.LOG, 'TIPO_DE_AJUSTE');
                  END IF;

--Fnd_File.put_line(Fnd_File.LOG,'Stage 15');
                  IF l_insert_second_map_row = 'NO'
                  THEN
                     -- C.Chan Mod 9/23/05 to track changes of Fecha_fin_prevista field
                     IF TO_CHAR (TO_DATE (NVL (r_emp.fecha_fin_prevista
                                             , '4712/12/31 00:00:00'
                                              )
                                        , 'YYYY/MM/DD hh24::mi:ss'
                                         )
                               , 'yyyy-mm-dd'
                                ) =
                           TO_CHAR
                               (TO_DATE (NVL (r_emp_prev.fecha_fin_prevista
                                            , '4712/12/31 00:00:00'
                                             )
                                       , 'YYYY/MM/DD hh24::mi:ss'
                                        )
                              , 'yyyy-mm-dd'
                               )
                     THEN
                        v_fecha_fin_prevista := NULL;
                     ELSE
                        v_fecha_fin_prevista :=
                           pad_data_output
                                ('VARCHAR2'
                               , 30
                               , TO_CHAR (TO_DATE (r_emp.fecha_fin_prevista
                                                 , 'YYYY/MM/DD hh24::mi:ss'
                                                  )
                                        , 'yyyy-mm-dd'
                                         )
                                );
                        v_tot_info_changed := v_tot_info_changed + 1;
                        l_map_update_date :=
                            TO_CHAR (r_emp.contract_update_date, 'yyyy-mm-dd');
                        fnd_file.put_line (fnd_file.LOG, 'FECHA_FIN_PREVISTA');
                     END IF;
                  END IF;

--Fnd_File.put_line(Fnd_File.LOG,'Stage 16');
-- Ken Mod 8/29/05 to track changes of Fecha_Inicio_Bonificacion and Fecha_Fin_Bonificacion fields
                  IF r_emp.fecha_inicio_bonificacion =
                                          r_emp_prev.fecha_inicio_bonificacion
                  THEN
                     v_fecha_inicio_bonificacion := NULL;
                  ELSE
                     IF r_emp.fecha_inicio_bonificacion IS NOT NULL
                     THEN
                        v_fecha_inicio_bonificacion :=
                           REPLACE (r_emp.fecha_inicio_bonificacion, '/'
                                  , '-');
                        v_tot_info_changed := v_tot_info_changed + 1;
                        l_map_update_date :=
                           TO_CHAR (r_emp.contract_update_date, 'yyyy-mm-dd');
                     --Fnd_File.put_line(Fnd_File.LOG,'FECHA_INICIO_BONIFICACION');
                     ELSE
                        v_fecha_inicio_bonificacion := NULL;
                     END IF;
                  END IF;

--Fnd_File.put_line(Fnd_File.LOG,'Stage 17');
                  IF r_emp.fecha_fin_bonificacion =
                                             r_emp_prev.fecha_fin_bonificacion
                  THEN
                     v_fecha_fin_bonificacion := NULL;
                  ELSE
                     IF r_emp.fecha_fin_bonificacion IS NOT NULL
                     THEN
                        v_fecha_fin_bonificacion :=
                             REPLACE (r_emp.fecha_fin_bonificacion, '/', '-');
                        v_tot_info_changed := v_tot_info_changed + 1;
                        l_map_update_date :=
                           TO_CHAR (r_emp.contract_update_date, 'yyyy-mm-dd');
                        fnd_file.put_line (fnd_file.LOG
                                         , 'FECHA_FIN_BONIFICACION'
                                          );
                     ELSE
                        v_fecha_fin_bonificacion := NULL;
                     END IF;
                  END IF;

                  --DBMS_OUTPUT.PUT_LINE(LENGTH(v_output));
                  IF v_tot_info_changed > 0
                  THEN
                     v_output :=
                        delimit_text
                           (iv_number_of_fields      => 52
                          , iv_field1                => pad_data_output
                                                                  ('VARCHAR2'
                                                                 , 16
                                                                 , 'MAP'
                                                                  )
                          , iv_field2                => pad_data_output
                                                            ('VARCHAR2'
                                                           , 30
                                                           , r_emp.employee_id
                                                            )
                          , iv_field3                => r_emp.ordinal_periodo
                          , iv_field4                => v_fecha_antiguedad
                          , iv_field5                => NULL
                          , iv_field6                => v_tipo_empleado
                          , iv_field7                => NULL
                          , iv_field8                => NULL
                                                    -- Ken Mod 7/18/05  pulled field9 and field10 when field10 is changed
                                                    -- field9=paaf.effective_start_date, field10=paaf.ass_attribute10
                          -- Matias 3/22,2006 email point 4) field # 9 is being populated with assignment start date and should be contract Start Date
                          --, iv_field9            => V_FECHA_INICIO_CONTRATO   -- Modify by C. Chan on 12/22/2005. Matias email requested this to be mandatory
                        ,   iv_field9                => v_fecha_inicio_cont_esp
                          , iv_field10               => v_id_contrato_interno
                                                         -- Ken Mod ending..
-- C. Chan Oct 31, 2005, Per Matias Boras, this need to be V_FECHA_FIN_PREVISTA instead of NULL
--                             , iv_field11            =>  NULL
                        ,   iv_field11               => v_fecha_fin_prevista
                          , iv_field12               => NULL
                          , iv_field13               => v_fecha_fin_contrato
-- Ken Mod 8/10/05 to pull Fecha_fin_periodo field from ctr_information4.per_contracts_f
-- and show it field #32 in NAEN section and field #14 in MAP section
                          --         , iv_field14            =>  NULL
-- C. Chan Oct 31, 2005, Per Matias Boras, Need to set this to NULL
--                                       , iv_field14   => V_FECHA_FIN_PERIODO
                        ,   iv_field14               => NULL
                          , iv_field15               => NULL
                          , iv_field16               => NULL
                          , iv_field17               => NULL
                          , iv_field18               => NULL
                          , iv_field19               => NULL
                          , iv_field20               => NULL
                          , iv_field21               => NULL
                          --  , iv_field22            => V_FECHA_INICIO_CONT_ESP  --Matias March 22, 2006 email point 5 Field#22 is being popultaed with Contract Start Date and should be blank
                        ,   iv_field22               => NULL
                          , iv_field23               => NULL
                          , iv_field24               => NULL
                          , iv_field25               => NULL
                          , iv_field26               => NULL
                          , iv_field27               => NULL
                          , iv_field28               => NULL
                          , iv_field29               => NULL
                          , iv_field30               => NULL
                          , iv_field31               => v_normal_hours_dt
                       -- Should have been delivered Phase 2 C. Chan 4/14/2006
                          , iv_field32               => v_normal_hours
                          , iv_field33               => v_papf_eff_dt
                          , iv_field34               => v_work_center
                          , iv_field35               => v_paaf_eff_dt
                          , iv_field36               => v_convenio
                          , iv_field37               => v_epigrafe_dt
                          , iv_field38               => v_epigrafe
                          , iv_field39               => v_grupo_tarifa_dt
                          , iv_field40               => v_grupo_tarifa
                          , iv_field41               => v_clave_percepcion_dt
                          , iv_field42               => v_clave_percepcion
                          , iv_field43               => v_tax_id
                          , iv_field44               => v_date_start
                          , iv_field45               => v_tipo_salario
                          , iv_field46               => v_tipo_eff_dt
                          , iv_field47               => v_tipo_de_ajuste
                          , iv_field48               => v_fecha_inicio_bonificacion
                          , iv_field49               => v_fecha_fin_bonificacion
--                             , iv_field50            => V_FECHA_INICIO_CONT_ESP  -- WO#147293 By C. Chan 12/22/05  Matias email requested this to be mandatory
--                             , iv_field51            => pad_data_output('VARCHAR2',30,TO_CHAR(to_date(r_emp.Fecha_fin_prevista,'YYYY/MM/DD hh24::mi:ss'),'yyyy-mm-dd'))
                        ,   iv_field50               => v_fecha_inicio_prorroga
                                                   -- added by CC on 3/16/2006
                          , iv_field51               => v_fecha_fin_prorroga
                                                   -- added by CC on 3/16/2006
                          , iv_field52               => l_map_update_date
                           );
                     print_line (v_output);
                  END IF;
               END IF;

               IF l_insert_first_map_row = 'YES'
               THEN
                         --Fnd_File.put_line(Fnd_File.LOG,'Stage 18');
                         --Fnd_File.put_line(Fnd_File.LOG,'l_insert_first_MAP_row = YES Block');
                         -- IF l_insert_first_MAP_row = 'NO'; i.e. l_insert_first_MAP_row = 'YES;
                         --
                         -- WO#147293 When a contract extension has to be informed, two consecutive MAP records should be informed
                  --  1. Contractact finishing
                  --     must have the following info:  Field # 1 Movement Type -> 'MAP''
                  --                                    Field # 2 Employee ID
                  --                                    Field # 3 Ordinal Period
                  --                                    Field # 9 Contract Start Date
                  --                                    Field #13 Contract End Date
                  --                                    The rest of the fields should be blank
                  --
                  --  2. Contract Extension
                  --     must have the following info:  Field # 1 Movement Type -> 'MAP''
                  --                                    Field # 2 Employee ID
                  --                                    Field # 3 Ordinal Period
                  --                                    Field # 9 Contract Start Date
                  --                                    Field #13 Contract End Date
                  --                                    Field #48 Contract Extention Start Date
                  --                                    Field #49 Contract Extention End Date
                  --                                    The rest of the fields should be blank
                  --
                  --
                  --  This section is inserting contract finishing information
                  --
                  v_output :=
                     delimit_text
                        (iv_number_of_fields      => 52
                       , iv_field1                => pad_data_output
                                                                  ('VARCHAR2'
                                                                 , 16
                                                                 , 'MAP'
                                                                  )
                       , iv_field2                => pad_data_output
                                                            ('VARCHAR2'
                                                           , 30
                                                           , r_emp.employee_id
                                                            )
                       , iv_field3                => r_emp.ordinal_periodo
                       , iv_field4                => NULL
                       , iv_field5                => NULL
                       , iv_field6                => NULL
                       , iv_field7                => NULL
                       , iv_field8                => NULL
                       , iv_field9                => v_fecha_inicio_cont_esp2
                       , iv_field10               => pad_data_output
                                                        ('VARCHAR2'
                                                       , 30
                                                       , r_emp.id_contrato_interno
                                                        )
                       , iv_field11               => NULL
                       , iv_field12               => NULL
                       , iv_field13               => v_fecha_fin_contrato2
                       , iv_field14               => NULL
                       , iv_field15               => NULL
                       , iv_field16               => NULL
                       , iv_field17               => NULL
                       , iv_field18               => NULL
                       , iv_field19               => NULL
                       , iv_field20               => NULL
                       , iv_field21               => NULL
                       , iv_field22               => NULL
                       , iv_field23               => NULL
                       , iv_field24               => NULL
                       , iv_field25               => NULL
                       , iv_field26               => NULL
                       , iv_field27               => NULL
                       , iv_field28               => NULL
                       , iv_field29               => NULL
                       , iv_field30               => NULL
                       , iv_field31               => NULL
                       , iv_field32               => NULL
                       , iv_field33               => NULL
                       , iv_field34               => NULL
                       , iv_field35               => NULL
                       , iv_field36               => NULL
                       , iv_field37               => NULL
                       , iv_field38               => NULL
                       , iv_field39               => NULL
                       , iv_field40               => NULL
                       , iv_field41               => NULL
                       , iv_field42               => NULL
                       , iv_field43               => NULL
                       , iv_field44               => NULL
                       , iv_field45               => NULL
                       , iv_field46               => NULL
                       , iv_field47               => NULL
                       , iv_field48               => NULL
                       , iv_field49               => NULL
                       , iv_field50               => NULL
                       , iv_field51               => NULL
                       , iv_field52               => l_map_update_date
                        );
                  print_line (v_output);
               END IF;

               IF l_insert_second_map_row = 'YES'
               THEN
                  --Fnd_File.put_line(Fnd_File.LOG,'l_insert_second_MAP_row = YES Block');
                        --
                  --  This section is inserting contract Extention information
                  --
                  v_output :=
                     delimit_text
                        (iv_number_of_fields      => 52
                       , iv_field1                => pad_data_output
                                                                  ('VARCHAR2'
                                                                 , 16
                                                                 , 'MAP'
                                                                  )
                       , iv_field2                => pad_data_output
                                                            ('VARCHAR2'
                                                           , 30
                                                           , r_emp.employee_id
                                                            )
                       , iv_field3                => r_emp.ordinal_periodo
                       , iv_field4                => NULL
                       , iv_field5                => NULL
                       , iv_field6                => NULL
                       , iv_field7                => NULL
                       , iv_field8                => NULL
                       , iv_field9                => v_fecha_inicio_cont_esp2
                       , iv_field10               => pad_data_output
                                                        ('VARCHAR2'
                                                       , 30
                                                       , r_emp.id_contrato_interno
                                                        )
                       , iv_field11               => NULL
                       , iv_field12               => NULL
                       , iv_field13               => NULL
                       , iv_field14               => NULL
                       , iv_field15               => NULL
                       , iv_field16               => NULL
                       , iv_field17               => NULL
                       , iv_field18               => NULL
                       , iv_field19               => NULL
                       , iv_field20               => NULL
                       , iv_field21               => NULL
                       , iv_field22               => NULL
                       , iv_field23               => NULL
                       , iv_field24               => NULL
                       , iv_field25               => NULL
                       , iv_field26               => NULL
                       , iv_field27               => NULL
                       , iv_field28               => NULL
                       , iv_field29               => NULL
                       , iv_field30               => NULL
                       , iv_field31               => NULL
                       , iv_field32               => NULL
                       , iv_field33               => NULL
                       , iv_field34               => NULL
                       , iv_field35               => NULL
                       , iv_field36               => NULL
                       , iv_field37               => NULL
                       , iv_field38               => NULL
                       , iv_field39               => NULL
                       , iv_field40               => NULL
                       , iv_field41               => NULL
                       , iv_field42               => NULL
                       , iv_field43               => NULL
                       , iv_field44               => NULL
                       , iv_field45               => NULL
                       , iv_field46               => NULL
                       , iv_field47               => NULL
                       , iv_field48               => NULL
                       , iv_field49               => NULL
                       , iv_field50               => v_fecha_inicio_prorroga
                                                   -- added by CC on 3/16/2006
                       , iv_field51               => v_fecha_fin_prorroga
                                                   -- added by CC on 3/16/2006
                       , iv_field52               => l_map_update_date
                        );
                  print_line (v_output);
               END IF;                    --IF l_insert_second_MAP_row = 'YES'
            EXCEPTION
               WHEN OTHERS
               THEN
                  fnd_file.put_line
                     (fnd_file.LOG
                    ,    'Error from Extract_emp_ assignment1_change getting old data. Employee id ->'
                      || r_emp.employee_id
                      || ' Contract NO ->'
                      || r_emp.id_contrato_interno
                      || ' Period NO ->'
                      || r_emp.ordinal_periodo
                     );
                  ov_retcode := SQLCODE;
                  ov_errbuf := SUBSTR (SQLERRM, 1, 255);
                  fnd_file.put_line (fnd_file.LOG, ov_errbuf);
            END;

            l_person_id := NULL;
            l_assignment_id := NULL;
            l_ass_eff_date := NULL;
            l_id_contrato_interno := '';
         END LOOP;                                           -- c_emp_prev_rec

         IF l_prev_rec_found = 'NO'
         THEN
            --Fnd_File.put_line(Fnd_File.LOG,'Stage 19');
            --Fnd_File.put_line(Fnd_File.LOG,'No previous rec found on employee id ->'|| r_emp.employee_id
            --                                                      ||   ' Contract NO' || r_emp.ID_CONTRATO_INTERNO
             --                                                      ||   ' Period NO'   || r_emp.ordinal_periodo);
            v_output :=
               delimit_text
                  (iv_number_of_fields      => 52
                 , iv_field1                => pad_data_output ('VARCHAR2'
                                                              , 16
                                                              , 'MAP'
                                                               )
                 , iv_field2                => pad_data_output
                                                            ('VARCHAR2'
                                                           , 30
                                                           , r_emp.employee_id
                                                            )
                 , iv_field3                => pad_data_output
                                                        ('VARCHAR2'
                                                       , 30
                                                       , r_emp.ordinal_periodo
                                                        )
                 , iv_field4                => REPLACE
                                                      (r_emp.fecha_antiguedad
                                                     , '/'
                                                     , '-'
                                                      )
                 , iv_field5                => NULL
                 , iv_field6                => NULL
                          --pad_data_output('VARCHAR2',30,r_emp.TIPO_EMPLEADO)
                 , iv_field7                => NULL
                 , iv_field8                => NULL
                 , iv_field9                => TO_CHAR
                                                  (r_emp.fecha_inicio_cont_específico
                                                 , 'yyyy-mm-dd'
                                                  )
                 , iv_field10               => pad_data_output
                                                    ('VARCHAR2'
                                                   , 30
                                                   , r_emp.id_contrato_interno
                                                    )
                 , iv_field11               => NULL
--pad_data_output('VARCHAR2',30,TO_CHAR(to_date(r_emp.Fecha_fin_prevista,'YYYY/MM/DD hh24::mi:ss'),'yyyy-mm-dd'))
                 , iv_field12               => NULL
                 , iv_field13               => TO_CHAR
                                                    (r_emp.fecha_fin_contrato
                                                   , 'yyyy-mm-dd'
                                                    )
                 , iv_field14               => NULL
                 , iv_field15               => NULL
                 , iv_field16               => NULL
                 , iv_field17               => NULL
                 , iv_field18               => NULL
                 , iv_field19               => NULL
                 , iv_field20               => NULL
                 , iv_field21               => NULL
                 , iv_field22               => NULL
                 , iv_field23               => NULL
                 , iv_field24               => NULL
                 , iv_field25               => NULL
                 , iv_field26               => NULL
                 , iv_field27               => NULL
                 , iv_field28               => NULL
                 , iv_field29               => NULL
                 , iv_field30               => NULL
                 , iv_field31               => TO_CHAR
                                                   (TRUNC (r_emp.ass_eff_date)
                                                  , 'yyyy-mm-dd'
                                                   )
                 , iv_field32               => pad_data_output
                                                           ('VARCHAR2'
                                                          , 30
                                                          , r_emp.normal_hours
                                                           )
                 , iv_field33               => NULL
                --NULL --TO_CHAR(TRUNC(r_emp.person_update_date),'yyyy-mm-dd')
                 , iv_field34               => NULL
                            --pad_data_output('VARCHAR2',30,r_emp.WORK_CENTER)
                 , iv_field35               => NULL
                             --TO_CHAR(TRUNC(r_emp.ass_eff_date),'yyyy-mm-dd')
                 , iv_field36               => NULL
                               --pad_data_output('VARCHAR2',30,r_emp.CONVENIO)
                 , iv_field37               => NULL
                              --TO_CHAR(TRUNC(r_emp.EpiGrafe_DT),'yyyy-mm-dd')
                 , iv_field38               => NULL
                               --pad_data_output('VARCHAR2',30,r_emp.EPIGRAFE)
                 , iv_field39               => NULL
                             --TO_CHAR(TRUNC(r_emp.ass_eff_date),'yyyy-mm-dd')
                 , iv_field40               => NULL
                           --pad_data_output('VARCHAR2',30,r_emp.GRUPO_TARIFA)
                 , iv_field41               => NULL
                       --TO_CHAR(TRUNC(r_emp.person_update_date),'yyyy-mm-dd')
                 , iv_field42               => NULL
                       --pad_data_output('VARCHAR2',30,r_emp.CLAVE_PERCEPCION)
                 , iv_field43               => NULL
                                 --pad_data_output('VARCHAR2',30,r_emp.TAX_ID)
                 , iv_field44               => NULL
                                      --TO_CHAR(r_emp.DATE_START,'yyyy-mm-dd')
                 , iv_field45               => NULL
                           --pad_data_output('VARCHAR2',30,r_emp.TIPO_SALARIO)
                 , iv_field46               => NULL
                       --TO_CHAR(TRUNC(r_emp.person_update_date),'yyyy-mm-dd')
                 , iv_field47               => NULL
                         --pad_data_output('VARCHAR2',30,r_emp.TIPO_DE_AJUSTE)
                 , iv_field48               => NULL
                            --replace(r_emp.Fecha_Inicio_Bonificacion,'/','-')
                 , iv_field49               => NULL
                               --replace(r_emp.Fecha_Fin_Bonificacion,'/','-')
                 , iv_field50               => NULL
                 , iv_field51               => NULL
                 , iv_field52               => TO_CHAR
                                                  (r_emp.contract_update_date
                                                 , 'yyyy-mm-dd'
                                                  )
                  );
            print_line (v_output);
         END IF;

         v_tot_info_changed := 0;
      END LOOP;                                                       -- c_emp
   EXCEPTION
      WHEN OTHERS
      THEN
         fnd_file.put_line (fnd_file.LOG
                          , 'Error from Extract_emp_ assignment1_change'
                           );
         ov_retcode := SQLCODE;
         ov_errbuf := SUBSTR (SQLERRM, 1, 255);
         fnd_file.put_line (fnd_file.LOG, ov_errbuf);
   END;                           -- procedure extract_emp_assignment1_changes

---===============================================
---==============================================
   PROCEDURE extract_emp_assignment2_change
   IS
      l_person_id              NUMBER;
      l_centros_de_coste       VARCHAR2 (1000);

      CURSOR c_emp
      IS
         SELECT DISTINCT tbpim.person_id, tbpim.costsegment_dt
                       , tbpim.ordinal_periodo, tbpim.employee_id
                       , tbpim.job_id, tbpim.new_job_id
                       , tbpim.centro_de_trabajo, tbpim.nivel_salarial
                       , tbpim.centros_de_coste, tbpim.person_update_date
                       , tbpim.ass_eff_date, tbpim.assignment_update_date
                       , tbpim.pcaf_update_date, tbpim.salary_update_date
                       , tbpim.costing_pct
                    --FROM cust.ttec_spain_pay_interface_mst tbpim    --code commented by RXNETHI-ARGANO,16/05/23
                    FROM apps.ttec_spain_pay_interface_mst tbpim     --code added by RXNETHI-ARGANO,16/05/23
                   WHERE tbpim.cut_off_date = g_cut_off_date
                     AND contract_pps_start_date !=
                                        g_cut_off_date
                                                      -- added by CC 4/14/2006
                     AND NVL (tbpim.contract_pps_end_date
                            , TO_DATE ('31-12-4712', 'dd-mm-yyyy')
                             ) >= g_cut_off_date
-- and  to_date(tbpim.FECHA_ANTIGUEDAD,'YYYY/MM/DD') != g_cut_off_date
                     AND tbpim.original_date_of_hire <
                            g_cut_off_date
                     -- Do not pick up new hires contracts, only existing ones
                     AND EXISTS (
                            ((SELECT tbpim1.person_id, tbpim1.job_id
                                   , tbpim1.new_job_id
                                   , tbpim1.centro_de_trabajo
                                   , tbpim1.nivel_salarial
                                   , tbpim1.centros_de_coste
                                   , tbpim1.costing_pct
                                --FROM cust.ttec_spain_pay_interface_mst tbpim1    --code commented by RXNETHI-ARGANO,16/05/23
                                FROM apps.ttec_spain_pay_interface_mst tbpim1      --code added by RXNETHI-ARGANO,16/05/23
                               WHERE tbpim1.cut_off_date = g_cut_off_date
                                 AND tbpim1.person_id = tbpim.person_id)
                             MINUS
                             (SELECT tbpim2.person_id, tbpim2.job_id
                                   , tbpim2.new_job_id
                                   , tbpim2.centro_de_trabajo
                                   , tbpim2.nivel_salarial
                                   , tbpim2.centros_de_coste
                                   , tbpim2.costing_pct
                                --FROM cust.ttec_spain_pay_interface_mst tbpim2    --code commented by RXNETHI-ARGANO,16/05/23
                                FROM apps.ttec_spain_pay_interface_mst tbpim2      --code added by RXNETHI-ARGANO,16/05/23
                               WHERE tbpim2.cut_off_date =
                                        (SELECT MAX (tbpim1.cut_off_date)
                                           --FROM cust.ttec_spain_pay_interface_mst tbpim1   --code commented by RXNETHI-ARGANO,16/05/23
                                           FROM apps.ttec_spain_pay_interface_mst tbpim1     --code added by RXNETHI-ARGANO,16/05/23
                                          WHERE tbpim1.person_id =
                                                               tbpim.person_id
                                            AND tbpim1.cut_off_date <
                                                                g_cut_off_date)
                                 AND tbpim2.person_id = tbpim.person_id)));

      CURSOR c_emp_prev_rec
      IS
         SELECT DISTINCT tbpim2.person_id, tbpim2.assignment_id
                       , tbpim2.employee_id, tbpim2.job_id, tbpim2.new_job_id
                       , tbpim2.centro_de_trabajo, tbpim2.nivel_salarial
                       , tbpim2.centros_de_coste, tbpim2.person_update_date
                       , tbpim2.ass_eff_date, tbpim2.costing_pct
                    --FROM cust.ttec_spain_pay_interface_mst tbpim2   --code commented by RXNETHI-ARGANO,16/05/23
                    FROM apps.ttec_spain_pay_interface_mst tbpim2     --code added by RXNETHI-ARGANO,16/05/23
                   WHERE tbpim2.cut_off_date =
                            (SELECT MAX (tbpim1.cut_off_date)
                               --FROM cust.ttec_spain_pay_interface_mst tbpim1   --code commented by RXNETHI-ARGANO,16/05/23
                               FROM apps.ttec_spain_pay_interface_mst tbpim1     --code added by RXNETHI-ARGANO,16/05/23
                              WHERE tbpim1.person_id = l_person_id
                                AND tbpim1.centros_de_coste =
                                                            l_centros_de_coste
                                AND tbpim1.cut_off_date < g_cut_off_date)
                     AND tbpim2.ass_eff_date =
                            (SELECT MAX (tbpim1.ass_eff_date)
                               --FROM cust.ttec_spain_pay_interface_mst tbpim1   --code commented by RXNETHI-ARGANO,16/05/23
                               FROM apps.ttec_spain_pay_interface_mst tbpim1     --code added by RXNETHI-ARGANO,16/05/23
                              WHERE tbpim1.person_id = l_person_id
                                AND tbpim1.centros_de_coste =
                                                            l_centros_de_coste
                                AND tbpim1.cut_off_date < g_cut_off_date)
                     AND tbpim2.person_id = l_person_id
                     AND tbpim2.centros_de_coste = l_centros_de_coste;

      v_output                 VARCHAR2 (4000);
      ov_retcode               NUMBER;
      ov_errbuf                VARCHAR2 (1000);
      v_job_id                 VARCHAR2 (1000);
      v_new_job_id             VARCHAR2 (1000);
      v_job_id_dt              VARCHAR2 (1000);
      v_departmento            VARCHAR2 (1000);
      v_departmento_dt         VARCHAR2 (1000);
      v_centro_de_trabajo      VARCHAR2 (1000);
      v_centro_de_trabajo_dt   VARCHAR2 (1000);
      v_salary_change_date     VARCHAR2 (1000);
      v_nivel_salarial         VARCHAR2 (1000);
      v_centros_de_coste       VARCHAR2 (1000);
      v_centros_de_coste_dt    VARCHAR2 (1000);
      v_costing_pct            VARCHAR2 (1000);
      l_prev_rec_found         VARCHAR2 (3);
      l_mar_update_date        VARCHAR2 (1000);
      v_tot_info_changed       NUMBER;
   BEGIN
      FOR r_emp IN c_emp
      LOOP
         l_person_id := r_emp.person_id;
         l_centros_de_coste := r_emp.centros_de_coste;
         l_prev_rec_found := 'NO';

         --Fnd_File.put_line(Fnd_File.LOG,'PERSON_ID'||l_person_id);
         FOR r_emp_prev IN c_emp_prev_rec
         LOOP
            BEGIN
               l_prev_rec_found := 'YES';
               v_tot_info_changed := 0;

               IF NVL (r_emp.new_job_id, 'X') =
                                             NVL (r_emp_prev.new_job_id, 'X')
               THEN
                  v_new_job_id := NULL;
               ELSE
                  v_new_job_id :=
                           pad_data_output ('VARCHAR2', 30, r_emp.new_job_id);
                  l_mar_update_date :=
                         TO_CHAR (r_emp.assignment_update_date, 'yyyy-mm-dd');
                  v_tot_info_changed := v_tot_info_changed + 1;
               --   Fnd_File.put_line(Fnd_File.LOG,'NEW_JOB_ID');
               END IF;

/* IF   r_emp.DEPARTMENTO = r_emp_prev.DEPARTMENTO THEN
         V_DEPARTMENTO := '0';
           V_DEPARTMENTO_DT := NULL;
    ELSE
         V_DEPARTMENTO := pad_data_output('VARCHAR2',30,r_emp.DEPARTMENTO) ;
        V_DEPARTMENTO_DT := TO_CHAR(r_emp.ass_eff_date,'yyyy-mm-dd');
    END IF;
*/
               IF NVL (r_emp.centro_de_trabajo, 'X') =
                                       NVL (r_emp_prev.centro_de_trabajo, 'X')
               THEN
                  v_centro_de_trabajo := NULL;
                  v_centro_de_trabajo_dt := NULL;
               ELSE
                  v_centro_de_trabajo :=
                     pad_data_output ('VARCHAR2', 30
                                    , r_emp.centro_de_trabajo);
                  v_centro_de_trabajo_dt :=
                                   TO_CHAR (r_emp.ass_eff_date, 'yyyy-mm-dd');
                  l_mar_update_date :=
                         TO_CHAR (r_emp.assignment_update_date, 'yyyy-mm-dd');
                  v_tot_info_changed := v_tot_info_changed + 1;
               END IF;

               IF NVL (r_emp.job_id, 'X') = NVL (r_emp_prev.job_id, 'X')
               THEN
                  v_job_id := NULL;
                  v_job_id_dt := NULL;
               ELSE
                  v_job_id := pad_data_output ('VARCHAR2', 30, r_emp.job_id);
                  v_job_id_dt := TO_CHAR (r_emp.ass_eff_date, 'yyyy-mm-dd');
                  v_new_job_id :=
                           pad_data_output ('VARCHAR2', 30, r_emp.new_job_id);
                  l_mar_update_date :=
                         TO_CHAR (r_emp.assignment_update_date, 'yyyy-mm-dd');
                  v_tot_info_changed := v_tot_info_changed + 1;
               -- V_DEPARTMENTO := pad_data_output('VARCHAR2',30,r_emp.DEPARTMENTO) ;
                -- V_DEPARTMENTO_DT := TO_CHAR(r_emp.ass_eff_date,'yyyy-mm-dd');
               END IF;

               IF NVL (r_emp.nivel_salarial, 'X') =
                                          NVL (r_emp_prev.nivel_salarial, 'X')
               THEN
                  v_nivel_salarial := NULL;
                  v_salary_change_date := NULL;
               ELSE
                  v_nivel_salarial :=
                       pad_data_output ('VARCHAR2', 30, r_emp.nivel_salarial);
                  v_salary_change_date :=
                                   TO_CHAR (r_emp.ass_eff_date, 'yyyy-mm-dd');
                  v_new_job_id :=
                           pad_data_output ('VARCHAR2', 30, r_emp.new_job_id);
                  l_mar_update_date :=
                             TO_CHAR (r_emp.salary_update_date, 'yyyy-mm-dd');
                  v_tot_info_changed := v_tot_info_changed + 1;
               END IF;

               IF NVL (r_emp.centros_de_coste, 'X') =
                                        NVL (r_emp_prev.centros_de_coste, 'X')
               THEN
                  v_centros_de_coste := NULL;
                  v_centros_de_coste_dt := NULL;
               ELSE
                  v_centros_de_coste :=
                     pad_data_output ('VARCHAR2', 30, r_emp.centros_de_coste);
                  v_centros_de_coste_dt :=
                                 TO_CHAR (r_emp.costsegment_dt, 'yyyy-mm-dd');
                  l_mar_update_date :=
                               TO_CHAR (r_emp.pcaf_update_date, 'yyyy-mm-dd');
                  v_tot_info_changed := v_tot_info_changed + 1;
               END IF;

               IF NVL (r_emp.costing_pct, 0) = NVL (r_emp_prev.costing_pct, 0)
               THEN
                  v_costing_pct := NULL;
                  v_centros_de_coste := NULL;
                  v_centros_de_coste_dt := NULL;
               ELSE
                  v_costing_pct :=
                                LTRIM (TO_CHAR (r_emp.costing_pct, '990.00'));
                  v_centros_de_coste :=
                     pad_data_output ('VARCHAR2', 30, r_emp.centros_de_coste);
                  v_centros_de_coste_dt :=
                                 TO_CHAR (r_emp.costsegment_dt, 'yyyy-mm-dd');
                  l_mar_update_date :=
                               TO_CHAR (r_emp.pcaf_update_date, 'yyyy-mm-dd');
                  v_tot_info_changed := v_tot_info_changed + 1;
               END IF;

               IF v_tot_info_changed > 0
               THEN
                  --Fnd_File.put_line(Fnd_File.LOG,'MAIN BLOCK'||l_person_id);
                  v_output :=
                     delimit_text
                            (iv_number_of_fields      => 16
                           , iv_field1                => pad_data_output
                                                                  ('VARCHAR2'
                                                                 , 16
                                                                 , 'MAR'
                                                                  )
                           , iv_field2                => pad_data_output
                                                            ('VARCHAR2'
                                                           , 30
                                                           , r_emp.employee_id
                                                            )
                           , iv_field3                => r_emp.ordinal_periodo
                           , iv_field4                => v_job_id_dt
                           , iv_field5                => v_job_id
                           , iv_field6                => NULL
                                                            --V_DEPARTMENTO_DT
                           , iv_field7                => NULL  --V_DEPARTMENTO
                           , iv_field8                => v_centro_de_trabajo_dt
                           , iv_field9                => v_centro_de_trabajo
                           , iv_field10               => v_salary_change_date
                           , iv_field11               => v_nivel_salarial
                           , iv_field12               => v_centros_de_coste_dt
                           , iv_field13               => v_centros_de_coste
                           , iv_field14               => v_new_job_id
                           , iv_field15               => l_mar_update_date
                           , iv_field16               => v_costing_pct
                            );
                  --DBMS_OUTPUT.PUT_LINE(LENGTH(v_output));
                  print_line (v_output);
               END IF;
            EXCEPTION
               WHEN OTHERS
               THEN
                  fnd_file.put_line
                     (fnd_file.LOG
                    ,    'Error from Extract_emp_ assignment2_change getting old data. Employee id ->'
                      || r_emp.employee_id
                      || ' Period NO'
                      || r_emp.ordinal_periodo
                     );
                  ov_retcode := SQLCODE;
                  ov_errbuf := SUBSTR (SQLERRM, 1, 255);
                  fnd_file.put_line (fnd_file.LOG, ov_errbuf);
            END;

            l_person_id := NULL;
         END LOOP;                                               -- r_emp_prev

         IF l_prev_rec_found = 'NO'
         THEN
            --Fnd_File.put_line(Fnd_File.LOG,'Prev Rec Not found'||l_person_id);
            v_output :=
               delimit_text
                      (iv_number_of_fields      => 16
                     , iv_field1                => pad_data_output
                                                                  ('VARCHAR2'
                                                                 , 16
                                                                 , 'MAR'
                                                                  )
                     , iv_field2                => pad_data_output
                                                            ('VARCHAR2'
                                                           , 30
                                                           , r_emp.employee_id
                                                            )
                     , iv_field3                => r_emp.ordinal_periodo
                     , iv_field4                => TO_CHAR
                                                          (r_emp.ass_eff_date
                                                         , 'yyyy-mm-dd'
                                                          )
                     , iv_field5                => pad_data_output
                                                                 ('VARCHAR2'
                                                                , 30
                                                                , r_emp.job_id
                                                                 )
                     , iv_field6                => NULL
                     , iv_field7                => NULL
                     , iv_field8                => TO_CHAR
                                                          (r_emp.ass_eff_date
                                                         , 'yyyy-mm-dd'
                                                          )
                     , iv_field9                => pad_data_output
                                                      ('VARCHAR2'
                                                     , 30
                                                     , r_emp.centro_de_trabajo
                                                      )
                     , iv_field10               => TO_CHAR
                                                          (r_emp.ass_eff_date
                                                         , 'yyyy-mm-dd'
                                                          )
                     , iv_field11               => pad_data_output
                                                         ('VARCHAR2'
                                                        , 30
                                                        , r_emp.nivel_salarial
                                                         )
                     , iv_field12               => TO_CHAR
                                                        (r_emp.costsegment_dt
                                                       , 'yyyy-mm-dd'
                                                        )
                     , iv_field13               => pad_data_output
                                                       ('VARCHAR2'
                                                      , 30
                                                      , r_emp.centros_de_coste
                                                       )
                     , iv_field14               => pad_data_output
                                                             ('VARCHAR2'
                                                            , 30
                                                            , r_emp.new_job_id
                                                             )
                     , iv_field15               => l_mar_update_date
                     , iv_field16               => LTRIM
                                                      (TO_CHAR
                                                           (r_emp.costing_pct
                                                          , '990.00'
                                                           )
                                                      )
                      );
            print_line (v_output);
         END IF;
      END LOOP;                                                       -- r_emp
   EXCEPTION
      WHEN OTHERS
      THEN
         fnd_file.put_line (fnd_file.LOG
                          , 'Error from Extract_emp_ assignment2_change'
                           );
         ov_retcode := SQLCODE;
         ov_errbuf := SUBSTR (SQLERRM, 1, 255);
   END;                           -- procedure extract_emp_assignment2_changes

---==============================================
---==============================================
   PROCEDURE extract_emp_salary_change
   IS
      l_person_id            NUMBER;
      l_ordinal_periodo      NUMBER;

      CURSOR c_emp
      IS
         SELECT DISTINCT tbpim.person_id, tbpim.employee_id
                       , tbpim.ordinal_periodo, tbpim.salary
                       , tbpim.salary_change_date, tbpim.salary_update_date
                    --FROM cust.ttec_spain_pay_interface_mst tbpim    --code commented by RXNETHI-ARGANO,16/05/23
                    FROM apps.ttec_spain_pay_interface_mst tbpim      --code added by RXNETHI-ARGANO,16/05/23
                   WHERE tbpim.cut_off_date = g_cut_off_date
                     AND tbpim.original_date_of_hire <
                            g_cut_off_date
                     -- Do not pick up new hires contracts, only existing ones
                     AND contract_pps_start_date != g_cut_off_date
                     AND NVL (tbpim.contract_pps_end_date
                            , TO_DATE ('31-12-4712', 'dd-mm-yyyy')
                             ) >= g_cut_off_date
-- and  to_date(tbpim.FECHA_ANTIGUEDAD,'YYYY/MM/DD') != g_cut_off_date
                     AND EXISTS (
                            ((SELECT tbpim1.person_id, tbpim1.ordinal_periodo
                                   , tbpim1.salary
                                --FROM cust.ttec_spain_pay_interface_mst tbpim1    --code commented by RXNETHI-ARGANO,16/05/23
                                FROM apps.ttec_spain_pay_interface_mst tbpim1      --code added by RXNETHI-ARGANO,16/05/23
                               WHERE tbpim1.cut_off_date = g_cut_off_date
                                 AND tbpim1.ordinal_periodo =
                                                         tbpim.ordinal_periodo
                                 AND tbpim1.person_id = tbpim.person_id)
                             MINUS
                             (SELECT tbpim2.person_id, tbpim2.ordinal_periodo
                                   , tbpim2.salary
                                --FROM cust.ttec_spain_pay_interface_mst tbpim2   --code commented by RXNETHI-ARGANO,16/05/23
                                FROM apps.ttec_spain_pay_interface_mst tbpim2     --code added by RXNETHI-ARGANO,16/05/23
                               WHERE tbpim2.cut_off_date =
                                        (SELECT MAX (tbpim1.cut_off_date)
                                           --FROM cust.ttec_spain_pay_interface_mst tbpim1   --code commented by RXNETHI-ARGANO,16/05/23
                                           FROM apps.ttec_spain_pay_interface_mst tbpim1     --code added by RXNETHI-ARGANO,16/05/23
                                          WHERE tbpim1.person_id =
                                                               tbpim.person_id
                                            AND tbpim1.ordinal_periodo =
                                                         tbpim.ordinal_periodo
                                            AND tbpim1.cut_off_date <
                                                                g_cut_off_date)
                                 AND tbpim2.person_id = tbpim.person_id)))
                 -- V1.0  Do not pickup reinstate in MAP record
                    AND NOT EXISTS (select 1
                                    --from cust.ttec_spain_pay_interface_mst tbpim1   --code commented by RXNETHI-ARGANO,16/05/23
                                    from apps.ttec_spain_pay_interface_mst tbpim1     --code added by RXNETHI-ARGANO,16/05/23
                                    where tbpim1.PERSON_ID = tbpim.PERSON_ID
                                    and   cut_off_date = g_cut_off_date - 1
                                    and assignment_status like 'Excedencia%');

      CURSOR c_emp_prev_rec
      IS
         SELECT DISTINCT tbpim2.salary
                    --FROM cust.ttec_spain_pay_interface_mst tbpim2   --code commented by RXNETHI-ARGANO,16/05/23
                    FROM apps.ttec_spain_pay_interface_mst tbpim2     --code added by RXNETHI-ARGANO,16/05/23
                   WHERE tbpim2.cut_off_date =
                            (SELECT MAX (tbpim1.cut_off_date)
                               --FROM cust.ttec_spain_pay_interface_mst tbpim1   --code commented by RXNETHI-ARGANO,16/05/23
                               FROM apps.ttec_spain_pay_interface_mst tbpim1     --code added by RXNETHI-ARGANO,16/05/23
                              WHERE tbpim1.person_id = l_person_id
                                AND tbpim1.ordinal_periodo = l_ordinal_periodo
                                AND tbpim1.cut_off_date < g_cut_off_date)
                     AND tbpim2.ass_eff_date =
                            (SELECT MAX (tbpim1.ass_eff_date)
                               --FROM cust.ttec_spain_pay_interface_mst tbpim1   --code commented by RXNETHI-ARGANO,16/05/23
                               FROM apps.ttec_spain_pay_interface_mst tbpim1     --code added by RXNETHI-ARGANO,16/05/23
                              WHERE tbpim1.person_id = l_person_id
                                AND tbpim1.ordinal_periodo = l_ordinal_periodo
                                AND tbpim1.cut_off_date < g_cut_off_date)
                     AND tbpim2.ordinal_periodo = l_ordinal_periodo
                     AND tbpim2.person_id = l_person_id;

      v_output               VARCHAR2 (4000);
      ov_retcode             NUMBER;
      ov_errbuf              VARCHAR2 (1000);
      v_salary_change_date   VARCHAR2 (1000);
      v_nivel_salarial       VARCHAR2 (1000);
      l_prev_rec_found       VARCHAR2 (3);
      l_mds_update_date      VARCHAR2 (1000);
      v_tot_info_changed     NUMBER;
   BEGIN
      FOR r_emp IN c_emp
      LOOP
         l_person_id := r_emp.person_id;
         l_ordinal_periodo := r_emp.ordinal_periodo;
         l_prev_rec_found := 'NO';
         fnd_file.put_line (fnd_file.LOG, 'PERSON_ID' || l_person_id);

         FOR r_emp_prev IN c_emp_prev_rec
         LOOP
            BEGIN
               l_prev_rec_found := 'YES';
               v_tot_info_changed := 0;

               IF NVL (r_emp.salary, 'X') = NVL (r_emp_prev.salary, 'X')
               THEN
                  v_nivel_salarial := NULL;
                  v_salary_change_date := NULL;
               ELSE
                  v_nivel_salarial :=
                               pad_data_output ('VARCHAR2', 30, r_emp.salary);
                  v_salary_change_date :=
                             TO_CHAR (r_emp.salary_change_date, 'yyyy-mm-dd');
                  l_mds_update_date :=
                             TO_CHAR (r_emp.salary_update_date, 'yyyy-mm-dd');
                  v_tot_info_changed := v_tot_info_changed + 1;
               --Fnd_File.put_line(Fnd_File.LOG,'SALARY');
               END IF;

               IF v_tot_info_changed > 0
               THEN
                  --Fnd_File.put_line(Fnd_File.LOG,'MAIN BLOCK'||l_person_id);
                  v_output :=
                     delimit_text
                        (iv_number_of_fields      => 6
                       , iv_field1                => pad_data_output
                                                                  ('VARCHAR2'
                                                                 , 16
                                                                 , 'MDS'
                                                                  )
                       , iv_field2                => pad_data_output
                                                            ('VARCHAR2'
                                                           , 30
                                                           , r_emp.employee_id
                                                            )
                       , iv_field3                => pad_data_output
                                                        ('VARCHAR2'
                                                       , 30
                                                       , r_emp.ordinal_periodo
                                                        )
                       , iv_field4                => v_salary_change_date
                       , iv_field5                => v_nivel_salarial
                       , iv_field6                => l_mds_update_date
                        );
                  --DBMS_OUTPUT.PUT_LINE(LENGTH(v_output));
                  print_line (v_output);
               END IF;
            EXCEPTION
               WHEN OTHERS
               THEN
                  fnd_file.put_line
                     (fnd_file.LOG
                    ,    'Error from Extract_emp_ salary_change getting old data. Employee id ->'
                      || r_emp.employee_id
                      || ' Period NO'
                      || r_emp.ordinal_periodo
                     );
                  ov_retcode := SQLCODE;
                  ov_errbuf := SUBSTR (SQLERRM, 1, 255);
                  fnd_file.put_line (fnd_file.LOG, ov_errbuf);
            END;

            l_person_id := NULL;
            l_ordinal_periodo := NULL;
         END LOOP;                                               -- r_emp_prev

         IF l_prev_rec_found = 'NO'
         THEN
            --Fnd_File.put_line(Fnd_File.LOG,'Prev Rec Not found'||l_person_id);
            v_output :=
               delimit_text
                        (iv_number_of_fields      => 6
                       , iv_field1                => pad_data_output
                                                                  ('VARCHAR2'
                                                                 , 16
                                                                 , 'MDS'
                                                                  )
                       , iv_field2                => pad_data_output
                                                            ('VARCHAR2'
                                                           , 30
                                                           , r_emp.employee_id
                                                            )
                       , iv_field3                => pad_data_output
                                                        ('VARCHAR2'
                                                       , 30
                                                       , r_emp.ordinal_periodo
                                                        )
                       , iv_field4                => TO_CHAR
                                                        (r_emp.salary_change_date
                                                       , 'yyyy-mm-dd'
                                                        )
                       , iv_field5                => r_emp.salary
                       , iv_field6                => l_mds_update_date
                        );
            print_line (v_output);
         END IF;
      END LOOP;                                                       -- r_emp
   EXCEPTION
      WHEN OTHERS
      THEN
         fnd_file.put_line (fnd_file.LOG
                          , 'Error from Extract_emp_ salary_change'
                           );
         ov_retcode := SQLCODE;
         ov_errbuf := SUBSTR (SQLERRM, 1, 255);
   END;                                -- procedure extract_emp_salary_changes

---=============================================
   PROCEDURE extract_emp_bankdata_change
   IS
      CURSOR c_emp
      IS
         SELECT DISTINCT tbpim.employee_id, tbpim.pppm_effective_date
                       , 'yyyy-mm-dd', tbpim.bank_name, tbpim.bank_branch
                       , tbpim.account_number, tbpim.control_id
                       , tbpim.tipo_de_pago, tbpim.banco_emisor
                       , tbpim.legal_employer, tbpim.bank_update_date
                    --FROM cust.ttec_spain_pay_interface_mst tbpim   --code commented by RXNETHI-ARGANO,16/05/23
                    FROM apps.ttec_spain_pay_interface_mst tbpim     --code added by RXNETHI-ARGANO,16/05/23
                   WHERE tbpim.last_extract_date =
                            (SELECT MAX (tbpim1.last_extract_date)
                               --FROM cust.ttec_spain_pay_interface_mst tbpim1   --code commented by RXNETHI-ARGANO,16/05/23
                               FROM apps.ttec_spain_pay_interface_mst tbpim1     --code added by RXNETHI-ARGANO,16/05/23
                              WHERE tbpim1.person_id = tbpim.person_id
                                AND tbpim1.bank_name = tbpim.bank_name
                                AND tbpim1.bank_branch = tbpim.bank_branch
                                AND tbpim1.account_number =
                                                          tbpim.account_number
                                AND tbpim1.control_id = tbpim.control_id
                                AND tbpim1.legal_employer =
                                                          tbpim.legal_employer
                                AND tbpim1.cut_off_date = g_cut_off_date)
                     AND tbpim.cut_off_date = g_cut_off_date
                     AND contract_pps_start_date !=
                                        g_cut_off_date
                                                      -- added by CC 4/14/2006
                     AND NVL (tbpim.contract_pps_end_date
                            , TO_DATE ('31-12-4712', 'dd-mm-yyyy')
                             ) >= g_cut_off_date
--    and  to_date(tbpim.FECHA_ANTIGUEDAD,'YYYY/MM/DD') != g_cut_off_date
                     AND    tbpim.bank_name
                         || tbpim.bank_branch
                         || tbpim.account_number
                         || tbpim.control_id
                         || tbpim.legal_employer NOT IN (
                            SELECT    tbpim2.bank_name
                                   || tbpim2.bank_branch
                                   || tbpim2.account_number
                                   || tbpim2.control_id
                                   || tbpim2.legal_employer
                              --FROM cust.ttec_spain_pay_interface_mst tbpim2   --code commented by RXNETHI-ARGANO,16/05/23
                              FROM apps.ttec_spain_pay_interface_mst tbpim2     --code added by RXNETHI-ARGANO,16/05/23
                             WHERE tbpim2.person_id = tbpim.person_id
                               AND (   (    tbpim2.bank_name <>
                                                               tbpim.bank_name
                                        AND tbpim2.bank_branch <>
                                                             tbpim.bank_branch
                                        AND tbpim2.account_number <>
                                                          tbpim.account_number
                                        AND tbpim2.control_id <>
                                                              tbpim.control_id
                                        AND tbpim2.legal_employer <>
                                                          tbpim.legal_employer
                                       )
                                    OR (    tbpim2.bank_name = tbpim.bank_name
                                        AND tbpim2.bank_branch =
                                                             tbpim.bank_branch
                                        AND tbpim2.account_number =
                                                          tbpim.account_number
                                        AND tbpim2.control_id =
                                                              tbpim.control_id
                                        AND tbpim2.legal_employer =
                                                          tbpim.legal_employer
                                       )
                                   )
                               AND tbpim2.cut_off_date < g_cut_off_date);

      v_output     VARCHAR2 (4000);
      ov_retcode   NUMBER;
      ov_errbuf    VARCHAR2 (1000);
   BEGIN
      --Print_line(' Employee bank Date Change');
      FOR r_emp IN c_emp
      LOOP
         v_output :=
            delimit_text (iv_number_of_fields      => 10
                        , iv_field1                => pad_data_output
                                                                  ('VARCHAR2'
                                                                 , 16
                                                                 , 'MDB'
                                                                  )
                        , iv_field2                => pad_data_output
                                                            ('VARCHAR2'
                                                           , 30
                                                           , r_emp.employee_id
                                                            )
                        , iv_field3                => TO_CHAR
                                                         (r_emp.pppm_effective_date
                                                        , 'yyyy-mm-dd'
                                                         )
                        , iv_field4                => pad_data_output
                                                              ('VARCHAR2'
                                                             , 30
                                                             , r_emp.bank_name
                                                              )
                        , iv_field5                => pad_data_output
                                                            ('VARCHAR2'
                                                           , 30
                                                           , r_emp.bank_branch
                                                            )
                        , iv_field6                => pad_data_output
                                                         ('VARCHAR2'
                                                        , 30
                                                        , r_emp.account_number
                                                         )
                        , iv_field7                => pad_data_output
                                                             ('VARCHAR2'
                                                            , 30
                                                            , r_emp.control_id
                                                             )
                        , iv_field8                => r_emp.tipo_de_pago
                        -- , iv_field9            =>  r_emp.banco_emisor
            ,             iv_field9                => r_emp.legal_employer
                                                                  -- WO#598085
                        , iv_field10               => TO_CHAR
                                                         (r_emp.bank_update_date
                                                        , 'yyyy-mm-dd'
                                                         )
                         );
         print_line (v_output);
      END LOOP;                                                       -- c_loc
   EXCEPTION
      WHEN OTHERS
      THEN
         fnd_file.put_line (fnd_file.LOG
                          , 'Error from Extract_emp_ bankdata_change'
                           );
         ov_retcode := SQLCODE;
         ov_errbuf := SUBSTR (SQLERRM, 1, 255);
   END;                              -- procedure extract_emp_bankdata_changes

--==============================================
   PROCEDURE extract_termination
   IS
      CURSOR c_term
      IS
/*
  SELECT DISTINCT person_id
  FROM   cust.ttec_spain_pay_interface_mst a
  WHERE  TRUNC(a.cut_off_date) = g_cut_off_date
   and    a.system_person_type = 'EX_EMP'   -- added by Ken
  AND    Ttec_Spain_Pay_Interface_Pkg.Record_Changed_V ('SYSTEM_PERSON_TYPE' , a.person_id, a.assignment_id, g_cut_off_date) = 'Y';
*/
         SELECT DISTINCT tbpim.employee_id, tbpim.ordinal_periodo
                       , tbpim.actual_termination_date, tbpim.leaving_reason
                       , tbpim.notified_termination_date
                       , tbpim.pps_update_date
                    --FROM cust.ttec_spain_pay_interface_mst tbpim   --code commented by RXNETHI-ARGANO,16/05/23
                    FROM apps.ttec_spain_pay_interface_mst tbpim     --code added by RXNETHI-ARGANO,16/05/23
                   WHERE tbpim.last_extract_date =
                            (SELECT MAX (tbpim1.last_extract_date)
                               --FROM cust.ttec_spain_pay_interface_mst tbpim1   --code commented by RXNETHI-ARGANO,16/05/23
                               FROM apps.ttec_spain_pay_interface_mst tbpim1     --code added by RXNETHI-ARGANO,16/05/23
                              WHERE tbpim1.person_id = tbpim.person_id
                                AND tbpim1.actual_termination_date IS NOT NULL
                                AND tbpim1.actual_termination_date =
                                                 tbpim.actual_termination_date
                                AND tbpim1.assignment_id = tbpim.assignment_id
                                AND tbpim1.cut_off_date = g_cut_off_date)
                     /* V 1.1  Begin commented out to allow future date termination */
--                     AND g_cut_off_date BETWEEN contract_pps_start_date
--                                            AND NVL
--                                                  (contract_pps_end_date
--                                                 , '31-DEC-4712'
--                                                  )         -- V 1.0 added NVL
                     /* V 1.1  End */
                     AND tbpim.actual_termination_date IS NOT NULL
                     AND tbpim.cut_off_date = g_cut_off_date
                     AND NOT EXISTS (
                            SELECT 1
                              --FROM cust.ttec_spain_pay_interface_mst tbpim2   --code commented by RXNETHI-ARGANO,16/05/23
                              FROM apps.ttec_spain_pay_interface_mst tbpim2     --code added by RXNETHI-ARGANO,16/05/23
                             WHERE tbpim2.person_id = tbpim.person_id
                               AND tbpim2.actual_termination_date IS NOT NULL
                               AND tbpim2.actual_termination_date =
                                                 tbpim.actual_termination_date
                               AND tbpim2.assignment_id = tbpim.assignment_id
                               AND tbpim2.cut_off_date < g_cut_off_date)
                ORDER BY tbpim.employee_id;

      v_output     VARCHAR2 (4000);
      ov_retcode   NUMBER;
      ov_errbuf    VARCHAR2 (1000);
   BEGIN
      --Print_line('TERMINATION');
      --Fnd_File.put_line(Fnd_File.LOG,'Extract Termination..');
      FOR r_term IN c_term
      LOOP
         -- Modify by C. Chan on 9/29/05
         -- Just process it here rather than issue another query to
         -- extract one employee data
         --get_term_emp_information(r_term.person_id);
         v_output :=
            delimit_text
               (iv_number_of_fields      => 7
              , iv_field1                => pad_data_output ('VARCHAR2'
                                                           , 16
                                                           , 'NBE'
                                                            )
              , iv_field2                => pad_data_output
                                                           ('VARCHAR2'
                                                          , 30
                                                          , r_term.employee_id
                                                           )
              , iv_field3                => r_term.ordinal_periodo
              , iv_field4                => TO_CHAR
                                               (r_term.actual_termination_date
                                              , 'yyyy-mm-dd'
                                               )
              , iv_field5                => pad_data_output
                                                        ('VARCHAR2'
                                                       , 30
                                                       , r_term.leaving_reason
                                                        )
              , iv_field6                => TO_CHAR
                                               (r_term.notified_termination_date
                                              , 'yyyy-mm-dd'
                                               )
                                        -- WO#150091 added By C.Chan 2/22/2005
              , iv_field7                => TO_CHAR (r_term.pps_update_date
                                                   , 'yyyy-mm-dd'
                                                    )
               );
         --DBMS_OUTPUT.PUT_LINE(LENGTH(v_output));
         print_line (v_output);
      END LOOP;
   EXCEPTION
      WHEN OTHERS
      THEN
         --Fnd_File.put_line(Fnd_File.LOG,'Error from Extract_termination');
         ov_retcode := SQLCODE;
         ov_errbuf := SUBSTR (SQLERRM, 1, 255);
   END;                                       -- procedure extract_termination
----===================================
--------------------------------------------------------------------
END;                              -- Package Body ttec_spain_pay_interface_pkg
/
show errors;
/