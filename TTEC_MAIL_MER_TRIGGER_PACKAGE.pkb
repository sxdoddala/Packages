create or replace PACKAGE body TTEC_MAIL_MER_TRIGGER_PACKAGE
AS
FUNCTION afterReportTrigger(
    P_ORG_NAME      IN VARCHAR2,
	P_TEMPLATE      IN NUMBER,
    P_INVOICE_NUM   IN VARCHAR2,
    P_PRINT_PENDING IN VARCHAR2)
  RETURN BOOLEAN
AS
  L_PRINT_PENDING   VARCHAR2(10);
  l_org_id          NUMBER;
  l_batch_source_id NUMBER;

  cursor c1 is
		SELECT DISTINCT hou.name OU,
		  rta_s.trx_number invoice_id,
		  RCTL_S.INTERFACE_LINE_ATTRIBUTE4 BUCODE,
		  PPA.SEGMENT1 PROGRAM_ID,
		  HOU.ORGANIZATION_ID,
		  RTA_S.PRINTING_COUNT,
		  RTA_S.PRINTING_PENDING, BATCH_SOURCE_ID--, to_char(PRINTING_LAST_PRINTED, 'DD-MON-YY HH24:MI:SS') last_printed
      , PRINTING_OPTION
		FROM apps.ra_customer_trx_lines_all rctl_s,
    apps.ra_customer_trx_all rta_s,
    apps.pa_projects_all ppa,
    apps.pa_project_customers_v pv,
    apps.hz_cust_acct_sites_all bcas,
    apps.hz_party_sites bhps,
    apps.hz_locations bhl,
    apps.hz_cust_acct_sites_all scas,
    apps.hz_party_sites shps,
    apps.hz_locations shl,
    apps.pa_project_contacts_v pacv,
    apps.hr_operating_units hou,
    APPS.RA_TERMS_TL RT,
    apps.pa_draft_invoices_all ph,
        APPS.PA_DRAFT_INVOICE_LINES_V PL,
        apps.ttec_bill_evnt_tsk_stg stg
        , PA.PA_PROJECTS_ALL PPA_TEMPLATE

  where 1                               = 1
  AND pl.project_id      = ph.project_id
      and PH.DRAFT_INVOICE_NUM = PL.DRAFT_INVOICE_NUM
      and STG.EVENT_ID(+)         = PL.EVENT_ID
      AND pl.line_num          = rctl_s.interface_line_attribute6
      and PH.RA_INVOICE_NUMBER = RTA_S.TRX_NUMBER
      and PH.SYSTEM_REFERENCE  = RCTL_S.CUSTOMER_TRX_ID
  AND ppa.segment1                      = rctl_s.interface_line_attribute1
  AND pv.bill_to_address_id             = bcas.cust_acct_site_id
  AND pv.ship_to_address_id             = scas.cust_acct_site_id
  AND bcas.party_site_id                = bhps.party_site_id
  AND bhps.location_id                  = bhl.location_id
  AND scas.party_site_id                = shps.party_site_id
  AND shps.location_id                  = shl.location_id
  AND pacv.project_id(+)                = pv.project_id
  AND pacv.customer_id(+)               = pv.customer_id
  AND pacv.project_contact_type_code(+) = 'BILLING'
  and PPA.PROJECT_ID                    = PV.PROJECT_ID
  AND rta_s.trx_number                  = nvl(P_INVOICE_NUM,rta_s.trx_number)
  AND rta_s.customer_trx_id             = rctl_s.customer_trx_id
  AND rta_s.org_id                      = hou.organization_id
  AND rta_s.term_id                     = rt.term_id
  AND RT.LANGUAGE                       = 'US'
  AND HOU.NAME = nvl(P_ORG_NAME,HOU.NAME)
  /*and HOU.name                          in (
   'TeleTech Singapore'
  ,'TeleTech Hong Kong'
  ,
  'RogenSi-AUS'
  ,'RogenSi-UK'
  ,'Guidon'
  , 'eLoyalty Canada'
  ,'PRG DUBAI'
  )*/
  and LINE_TYPE                         <> 'TAX'
  AND RTA_S.PRINTING_OPTION             = 'PRI'
  AND RTA_S.PRINTING_PENDING             <> P_PRINT_PENDING
  AND PPA_TEMPLATE.PROJECT_ID            = PPA.CREATED_FROM_PROJECT_ID
  AND PPA_TEMPLATE.TEMPLATE_FLAG          = 'Y'
  AND PPA_TEMPLATE.PROJECT_ID             = NVL(P_TEMPLATE, PPA_TEMPLATE.PROJECT_ID)
  AND PPA_TEMPLATE.PROJECT_ID IN (SELECT PROJECT_ID FROM TTEC_PROJECT_TEMPLATES_V)
  order by hou.name;

   L_PRINT varchar2(10):=null;
BEGIN
  /*IF P_PRINT_PENDING IS NULL OR P_PRINT_PENDING='N' THEN
  L_PRINT := 'N';
  ELSIF P_PRINT_PENDING = 'Y' then
  L_PRINT := 'Y';
  END IF;*/
 L_PRINT := P_PRINT_PENDING;


  SELECT ORGANIZATION_ID
  INTO l_org_id
  FROM HR_OPERATING_UNITS
  WHERE name = P_ORG_NAME;

  /*

  SELECT PRINTING_PENDING
  INTO L_PRINT_PENDING
  FROM RA_CUSTOMER_TRX_ALL
  WHERE TRX_NUMBER = P_INVOICE_NUM
  AND ORG_ID       = l_org_id;

  SELECT BATCH_SOURCE_ID
  INTO l_batch_source_id
  FROM RA_BATCH_SOURCES_ALL
  where name = 'PROJECTS INVOICES'
  AND org_id = l_org_id;*/

SELECT BATCH_SOURCE_ID
  INTO l_batch_source_id
  FROM RA_BATCH_SOURCES_ALL
  WHERE NAME = 'PROJECTS INVOICES'
  AND org_id = l_org_id;

BEGIN
  --L_PRINT := P_PRINT_PENDING;
FOR c1_rec in c1
loop


    -- P_PRINT_PENDING : Re-Print
IF L_PRINT ='Y' THEN

  IF C1_REC.PRINTING_PENDING = 'N' THEN
    --if  l_batch_source_id = c1_rec.batch_source_id then
			UPDATE RA_CUSTOMER_TRX_ALL
			SET PRINTING_LAST_PRINTED = sysdate ,
				PRINTING_COUNT          = nvl(c1_rec.PRINTING_COUNT,0)+1
				WHERE TRX_NUMBER          = to_char(c1_rec.invoice_id)
				AND ORG_ID                = c1_rec.organization_id
				AND PRINTING_OPTION       = 'PRI'
				--AND BATCH_SOURCE_ID       = L_BATCH_SOURCE_ID;
				AND BATCH_SOURCE_ID       = c1_rec.BATCH_SOURCE_ID;
				COMMIT;
      --end if;

	END IF;
ELSIF L_PRINT  = 'N' THEN
		IF C1_REC.PRINTING_PENDING = 'Y' THEN

    BEGIN
    --if  l_batch_source_id = c1_rec.batch_source_id then
			UPDATE RA_CUSTOMER_TRX_ALL
			SET PRINTING_PENDING     = 'N' ,
				PRINTING_LAST_PRINTED  = sysdate ,
				PRINTING_ORIGINAL_DATE = sysdate ,
				PRINTING_COUNT         = NVL(C1_REC.PRINTING_COUNT,0)+1
				WHERE TRX_NUMBER         = to_char(c1_rec.invoice_id)
				AND ORG_ID               = c1_rec.organization_id
				AND PRINTING_OPTION      = 'PRI'
				--AND batch_source_id      = l_batch_source_id;
				AND BATCH_SOURCE_ID       = c1_rec.BATCH_SOURCE_ID;
				COMMIT;
    --end if;

      EXCEPTION
        WHEN NO_DATA_FOUND THEN
        null;
        WHEN OTHERS THEN
        null;
      END;
	END IF;
END IF;

end loop;

exception
  when others then
      RETURN TRUE;
end;
    RETURN true;
END;
END;
/
show errors;
/