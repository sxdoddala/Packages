create or replace PACKAGE BODY     ttec_MAIL_MERGE_report AS


 /************************************************************************************
        Program Name: TTEC_MAIL_MERGE_REPORT 

        Description:   

        Developed by : 
        Date         :  

       Modification Log
       Name                  Version #    Date            Description
       -----                 --------     -----           -------------
    RXNETHI(ARGANO)            1.0      18-May-2023      R12.2 Upgrade Remediation
    ****************************************************************************************/





  PROCEDURE main(retcode     OUT NUMBER,
                              errbuf        OUT VARCHAR2,
                              P_ORG_NAME IN varchar2,
                              P_TEMPLATE IN varchar2,
                              P_INVOICE_NUM IN varchar2,

                              P_PRINT_PENDING IN varchar2

                             )
 IS
 cursor c1 (P_INVOICE_NUM varchar2, P_ORG_NAME varchar2,P_PRINT_PENDING varchar2, P_TEMPLATE varchar2)
is
SELECT distinct invoice_id InvoiceID ,
  BUCODE BUCode,

  INVOICE_CONTACT InvoiceContactFirstName ,
  NULL InvoiceContactLastName ,
  NULL InvoiceContactPosition ,
  customer_name InvoiceContactAddressee ,
  address1 InvoiceContactAddress1 ,
  address2 InvoiceContactAddress2 ,
  city InvoiceContactAddressCity ,
  ST_PROVICE InvoiceContactAddressState ,
  postal_code InvoiceContactAddressPostcode ,
  NULL InvoiceContactAddressCountry ,
  purchase_order InvClientPONumber ,
  invoice_date InvDate ,
  TAX_CLASSIFICATION_CODE TaxDescription ,
  --inv_narrative InvNarrative ,
  --inv_exp_narrative InvExpNarrative ,
  NULL InvOnlineNarrative ,
 -- special_instruction SpecialInstructions ,
  invoice_currency_code CCYCode ,
  NULL ProgramType ,
  program_id ProgramID ,
  NVL(inv_fees_ex_tax,0) InvFeesExTax ,
  NVL(inv_tax_expns_ex_tax,0) InvTaxExpnsExTax ,
  NVL(inv_no_tax_expns,0) InvNoTaxExpns,
  (NVL(inv_fees_ex_tax,0) + NVL(inv_tax_expns_ex_tax,0) + NVL(inv_no_tax_expns,0) ) InvTotalExTax,
  NVL(inv_tax_amount,0) InvTaxAmount,
  ( NVL(inv_fees_ex_tax,0) + NVL(inv_tax_expns_ex_tax,0) + NVL(inv_no_tax_expns,0) + NVL(inv_tax_amount,0) ) InvTotalIncTax ,
  invoice_id InvoiceNumber ,
  payment_term PaymentMethod ,
  customer_number ClientID ,
  OU GPOffice,
  template_name
FROM
  (SELECT hou.name OU,
    rta_s.trx_number invoice_id,
    RCTL_S.INTERFACE_LINE_ATTRIBUTE4 BUCODE,


  (
    SELECT listagg(o.invoice_contact ,'|') within GROUP (
    ORDER BY o.invoice_contact) AS invoice_contact
    from
      (select
        distinct (SELECT  stg.invoice_contact
        FROM apps.pa_draft_invoices_all ph,
          apps.pa_draft_invoice_lines_v pl,
          apps.ttec_bill_evnt_tsk_stg stg
        WHERE pl.project_id      = ph.project_id
        and PH.DRAFT_INVOICE_NUM = PL.DRAFT_INVOICE_NUM
        AND STG.EVENT_ID(+)      = PL.EVENT_ID
        AND PL.LINE_NUM          = RCTL_SS.INTERFACE_LINE_ATTRIBUTE6
        AND PH.RA_INVOICE_NUMBER = RTA_SS.TRX_NUMBER
        and PH.SYSTEM_REFERENCE  = RCTL_SS.CUSTOMER_TRX_ID
        --and stg.invoice_contact is not null
        ) invoice_contact, RTA_SS.TRX_NUMBER, hou.name
      FROM APPS.RA_CUSTOMER_TRX_LINES_ALL RCTL_SS,
        apps.ra_customer_trx_all rta_ss,
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
        apps.ra_terms_tl rt
      WHERE 1                               = 1
      AND ppa.segment1                      = rctl_ss.interface_line_attribute1
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
      AND RTA_Ss.CUSTOMER_TRX_ID            = RCTL_Ss.CUSTOMER_TRX_ID
      AND RTA_SS.ORG_ID                     = HOU.ORGANIZATION_ID
      AND rta_ss.term_id                    = rt.term_id
      and RT.LANGUAGE                       = 'US'
      AND line_type                        <> 'TAX'
      ) O
      where RTA_S.TRX_NUMBER = O.TRX_NUMBER
      and hou.name = o.name
    ) invoice_contact,
    pv.customer_name,
    bhl.address1,
    bhl.address2,
    bhl.address3,
    bhl.address4,
    bhl.city,
    NVL (bhl.state, bhl.province) st_provice,
    bhl.postal_code,
    TRIM (TO_CHAR (rta_s.trx_date, 'Month'))
    || ' '
    || TO_CHAR (rta_s.trx_date, 'dd')
    || ','
    || TO_CHAR (rta_s.trx_date, 'yyyy') invoice_date,
	(
 SELECT DISTINCT PAA.CUSTOMER_ORDER_NUMBER FROM APPS.PA_AGREEMENTS_ALL PAA
WHERE PAA.AGREEMENT_ID = Ph.AGREEMENT_ID
) PURCHASE_ORDER,
    --rta_s.purchase_order,
   (SELECT TAX_RATE_CODE
    FROM apps.zx_lines
    WHERE APPLICATION_ID = 222

    AND Tax_rate > 0
    AND TRX_ID   = RCTL_S.CUSTOMER_TRX_ID
    AND rownum   =1
    ) TAX_CLASSIFICATION_CODE,


    rta_s.invoice_currency_code,
    ppa.segment1 program_id,
    DECODE (
    (SELECT DISTINCT stg.trans_type FROM apps.pa_draft_invoices_all ph,
      apps.pa_draft_invoice_lines_v pl,
      apps.ttec_bill_evnt_tsk_stg stg WHERE pl.project_id = ph.project_id
    AND ph.draft_invoice_num                              = pl.draft_invoice_num
    AND stg.event_id                                      = pl.event_id
    AND pl.line_num                                       = rctl_s.interface_line_attribute6
    AND ph.ra_invoice_number                              = rta_s.trx_number
    AND ph.system_reference                               = rctl_s.customer_trx_id
    ), NULL, 'EVENT',
    (SELECT DISTINCT stg.trans_type
    FROM apps.pa_draft_invoices_all ph,
      apps.pa_draft_invoice_lines_v pl,
      apps.ttec_bill_evnt_tsk_stg stg
    WHERE pl.project_id      = ph.project_id
    AND ph.draft_invoice_num = pl.draft_invoice_num
    AND stg.event_id         = pl.event_id
    AND pl.line_num          = rctl_s.interface_line_attribute6
    AND ph.ra_invoice_number = rta_s.trx_number
    AND ph.system_reference  = rctl_s.customer_trx_id
    ) ) event_type,
    (
    (SELECT NVL(SUM (t.revenue_amount),0)
    FROM
      (SELECT revenue_amount,
        rctl.customer_trx_id,
        rta.trx_number,
        DECODE (
        (SELECT DISTINCT stg.trans_type FROM apps.pa_draft_invoices_all ph,
          apps.pa_draft_invoice_lines_v pl,
          apps.ttec_bill_evnt_tsk_stg stg WHERE pl.project_id = ph.project_id
        AND ph.draft_invoice_num                              = pl.draft_invoice_num
        AND stg.event_id                                      = pl.event_id
        AND pl.line_num                                       = rctl.interface_line_attribute6
        AND ph.ra_invoice_number                              = rta.trx_number
        AND ph.system_reference                               = rctl.customer_trx_id
        ), NULL, 'EVENT',
        (SELECT DISTINCT stg.trans_type
        FROM apps.pa_draft_invoices_all ph,
          apps.pa_draft_invoice_lines_v pl,
          apps.ttec_bill_evnt_tsk_stg stg
        WHERE pl.project_id      = ph.project_id
        AND ph.draft_invoice_num = pl.draft_invoice_num
        AND stg.event_id         = pl.event_id
        AND pl.line_num          = rctl.interface_line_attribute6
        AND ph.ra_invoice_number = rta.trx_number
        AND ph.system_reference  = rctl.customer_trx_id
        ) ) event_type
      FROM apps.ra_customer_trx_lines_all rctl,
        apps.ra_customer_trx_all rta
      WHERE 1                 = 1
      AND rta.customer_trx_id = rctl.customer_trx_id
      AND line_type          <> 'TAX'
      ) t
    WHERE t.event_type    = 'EVENT'
    AND t.trx_number      = rta_s.trx_number
    AND t.customer_trx_id = rctl_s.customer_trx_id
    GROUP BY t.trx_number
    )) inv_fees_ex_tax,
    (
    (SELECT NVL(SUM (t.revenue_amount),0)
    FROM
      (SELECT rctl.revenue_amount,
        rctl.customer_trx_id,
        rta.trx_number,
        NVL(
        (SELECT tax_rate
        FROM apps.zx_lines
        WHERE application_id = 222
        AND trx_line_id      = rctl.customer_trx_line_id
        AND trx_id           = rctl.customer_trx_id
        ),0) tax_rate,
        DECODE (
        (SELECT DISTINCT stg.trans_type FROM apps.pa_draft_invoices_all ph,
          apps.pa_draft_invoice_lines_v pl,
          apps.ttec_bill_evnt_tsk_stg stg WHERE pl.project_id = ph.project_id
        AND ph.draft_invoice_num                              = pl.draft_invoice_num
        AND stg.event_id                                      = pl.event_id
        AND pl.line_num                                       = rctl.interface_line_attribute6
        AND ph.ra_invoice_number                              = rta.trx_number
        AND ph.system_reference                               = rctl.customer_trx_id
      ), NULL, 'EVENT',
        (SELECT stg.trans_type
        FROM apps.pa_draft_invoices_all ph,
          apps.pa_draft_invoice_lines_v pl,
          apps.ttec_bill_evnt_tsk_stg stg
        WHERE pl.project_id      = ph.project_id
        AND ph.draft_invoice_num = pl.draft_invoice_num
        AND stg.event_id         = pl.event_id
        AND pl.line_num          = rctl.interface_line_attribute6
        AND ph.ra_invoice_number = rta.trx_number
        AND ph.system_reference  = rctl.customer_trx_id
        ) ) event_type
      FROM apps.ra_customer_trx_lines_all rctl,
        apps.ra_customer_trx_all rta
      WHERE 1                 = 1
      AND rta.customer_trx_id = rctl.customer_trx_id
      AND rctl.line_type     <> 'TAX'
      ) t
    WHERE t.event_type    = 'EXP'
    AND t.tax_rate       <> 0
    AND t.trx_number      = rta_s.trx_number
    AND t.customer_trx_id = rctl_s.customer_trx_id
    GROUP BY t.trx_number
    )) inv_tax_expns_ex_tax,
    (
    (SELECT NVL(SUM (t.revenue_amount),0)
    FROM
      (SELECT rctl.revenue_amount,
        rctl.customer_trx_id,
        rta.trx_number,
        DECODE (
        (SELECT DISTINCT stg.trans_type FROM apps.pa_draft_invoices_all ph,
          apps.pa_draft_invoice_lines_v pl,
          apps.ttec_bill_evnt_tsk_stg stg WHERE pl.project_id = ph.project_id
        AND ph.draft_invoice_num                              = pl.draft_invoice_num
        AND stg.event_id                                      = pl.event_id
        AND pl.line_num                                       = rctl.interface_line_attribute6
        AND ph.ra_invoice_number                              = rta.trx_number
        AND ph.system_reference                               = rctl.customer_trx_id
        ), NULL, 'EVENT',
        (SELECT DISTINCT stg.trans_type
        FROM apps.pa_draft_invoices_all ph,
          apps.pa_draft_invoice_lines_v pl,
          apps.ttec_bill_evnt_tsk_stg stg
        WHERE pl.project_id      = ph.project_id
        AND ph.draft_invoice_num = pl.draft_invoice_num
        AND stg.event_id         = pl.event_id
        AND pl.line_num          = rctl.interface_line_attribute6
        AND ph.ra_invoice_number = rta.trx_number
        AND ph.system_reference  = rctl.customer_trx_id
        ) ) event_type,
        NVL(
        (SELECT tax_rate
        FROM apps.zx_lines
        WHERE application_id = 222
        AND trx_line_id      = rctl.customer_trx_line_id
        AND trx_id           = rctl.customer_trx_id
        ),0) tax_rate
      FROM apps.ra_customer_trx_lines_all rctl,
        apps.ra_customer_trx_all rta
      WHERE 1                 = 1
      AND rta.customer_trx_id = rctl.customer_trx_id
      AND line_type          <> 'TAX'
      ) t
    WHERE t.event_type    = 'EXP'
    AND t.tax_rate        = 0
    AND t.trx_number      = rta_s.trx_number
    AND t.customer_trx_id = rctl_s.customer_trx_id
    GROUP BY t.trx_number
    )) inv_no_tax_expns,
    (
    (SELECT NVL(SUM (t.tax_recoverable),0)
    FROM
      (SELECT rctl.tax_recoverable,
        rctl.customer_trx_id,
        rta.trx_number,
        DECODE (
        (SELECT DISTINCT stg.trans_type FROM apps.pa_draft_invoices_all ph,
          apps.pa_draft_invoice_lines_v pl,
          apps.ttec_bill_evnt_tsk_stg stg WHERE pl.project_id = ph.project_id
        AND ph.draft_invoice_num                              = pl.draft_invoice_num
        AND stg.event_id                                      = pl.event_id
        AND pl.line_num                                       = rctl.interface_line_attribute6
        AND ph.ra_invoice_number                              = rta.trx_number
        AND ph.system_reference                               = rctl.customer_trx_id
        ), NULL, 'EVENT',
        (SELECT DISTINCT stg.trans_type
        FROM apps.pa_draft_invoices_all ph,
          apps.pa_draft_invoice_lines_v pl,
          apps.ttec_bill_evnt_tsk_stg stg
        WHERE pl.project_id      = ph.project_id
        AND ph.draft_invoice_num = pl.draft_invoice_num
        AND stg.event_id         = pl.event_id
        AND pl.line_num          = rctl.interface_line_attribute6
        AND ph.ra_invoice_number = rta.trx_number
        AND ph.system_reference  = rctl.customer_trx_id
        ) ) event_type,
        NVL(
        (SELECT tax_rate
        FROM apps.zx_lines
        WHERE application_id = 222
        AND trx_line_id      = rctl.customer_trx_line_id
        AND trx_id           = rctl.customer_trx_id
        ),0) tax_rate
      FROM apps.ra_customer_trx_lines_all rctl,
        apps.ra_customer_trx_all rta
      WHERE 1                 = 1
      AND rta.customer_trx_id = rctl.customer_trx_id
      AND rctl.line_type     <> 'TAX'
      ) t
    WHERE t.trx_number    = rta_s.trx_number
    AND t.customer_trx_id = rctl_s.customer_trx_id
    GROUP BY t.trx_number
    )) inv_tax_amount ,
    PV.CUSTOMER_NUMBER ,
    rt.description payment_term, PPA_TEMPLATE.name template_name
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
        --, PA.PA_PROJECTS_ALL PPA_TEMPLATE    --code commented by RXNETHI-ARGANO,18/05/23
        , APPS.PA_PROJECTS_ALL PPA_TEMPLATE    --code added by RXNETHI-ARGANO,18/05/23

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
  and LINE_TYPE                         <> 'TAX'
  AND RTA_S.PRINTING_OPTION             = 'PRI'
  AND RTA_S.PRINTING_PENDING             <> P_PRINT_PENDING
  AND PPA_TEMPLATE.PROJECT_ID            = PPA.CREATED_FROM_PROJECT_ID
  AND PPA_TEMPLATE.TEMPLATE_FLAG          = 'Y'
  and PPA_TEMPLATE.project_id             = nvl(P_TEMPLATE, PPA_TEMPLATE.project_id)
  AND PPA_TEMPLATE.PROJECT_ID IN (SELECT PROJECT_ID FROM TTEC_PROJECT_TEMPLATES_V)
  order by hou.name
  )
ORDER BY OU;

cursor c2_inv_exp_narrative(P_ORG_NAME varchar2, P_INVOICE_ID varchar2)
is
SELECT DECODE (
        (SELECT DISTINCT stg.trans_type FROM apps.pa_draft_invoices_all ph,
          apps.pa_draft_invoice_lines_v pl,
          apps.ttec_bill_evnt_tsk_stg stg WHERE pl.project_id = ph.project_id
        AND ph.draft_invoice_num                              = pl.draft_invoice_num
        AND stg.event_id                                      = pl.event_id
        AND pl.line_num                                       = RCTL_SS.INTERFACE_LINE_ATTRIBUTE6
        AND ph.ra_invoice_number                              = rta_ss.trx_number
        AND ph.system_reference                               = RCTL_SS.CUSTOMER_TRX_ID
        ), 'EXP', RCTL_SS.DESCRIPTION
        ||'|'||' Dates :'
        ||
        (SELECT DISTINCT stg.invoice_start_date
          ||' to '
          ||stg.invoice_end_date
        FROM apps.pa_draft_invoices_all ph,
          apps.pa_draft_invoice_lines_v pl,
          apps.ttec_bill_evnt_tsk_stg stg
       WHERE pl.project_id      = ph.project_id
        AND ph.draft_invoice_num = pl.draft_invoice_num
        AND stg.event_id         = pl.event_id
        AND pl.line_num          = RCTL_SS.INTERFACE_LINE_ATTRIBUTE6
        AND PH.RA_INVOICE_NUMBER = RTA_SS.TRX_NUMBER
        AND PH.SYSTEM_REFERENCE  = RCTL_Ss.CUSTOMER_TRX_ID
        )
        ||'|'
        ||
        (SELECT DECODE(TAX_RATE,0,'Non ','')
        FROM apps.zx_lines
        WHERE APPLICATION_ID = 222
        AND TRX_LINE_ID      = RCTL_SS.CUSTOMER_TRX_LINE_ID
        AND TRX_ID           = RCTL_Ss.CUSTOMER_TRX_ID
        )
        ||'Taxable Expenses :'
        ||revenue_amount, NULL ) inv_exp_narrative, RTA_SS.TRX_NUMBER, hou.name
      FROM APPS.RA_CUSTOMER_TRX_LINES_ALL RCTL_SS,
        apps.ra_customer_trx_all rta_ss,
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
        apps.ra_terms_tl rt
      WHERE 1                               = 1
      AND ppa.segment1                      = rctl_ss.interface_line_attribute1
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
      AND RTA_Ss.CUSTOMER_TRX_ID            = RCTL_Ss.CUSTOMER_TRX_ID
      AND RTA_SS.ORG_ID                     = HOU.ORGANIZATION_ID
      AND rta_ss.term_id                    = rt.term_id
      and RT.LANGUAGE                       = 'US'
      AND LINE_TYPE                        <> 'TAX'
      AND RTA_SS.TRX_NUMBER=P_INVOICE_ID
      AND hou.name=P_ORG_NAME;



cursor c3_special_instruction(P_ORG_NAME varchar2, P_INVOICE_ID varchar2)
is
select
        (SELECT distinct stg.attribute1
        FROM apps.pa_draft_invoices_all ph,
          apps.pa_draft_invoice_lines_v pl,
          apps.ttec_bill_evnt_tsk_stg stg
        WHERE pl.project_id      = ph.project_id
        AND ph.draft_invoice_num = pl.draft_invoice_num
        AND STG.EVENT_ID(+)      = PL.EVENT_ID
        AND PL.LINE_NUM          = RCTL_SS.INTERFACE_LINE_ATTRIBUTE6
        AND PH.RA_INVOICE_NUMBER = RTA_SS.TRX_NUMBER
        and PH.SYSTEM_REFERENCE  = RCTL_SS.CUSTOMER_TRX_ID
        and stg.attribute1 is not null and rownum=1
        ) special_instruction, RTA_SS.TRX_NUMBER, hou.name
      FROM APPS.RA_CUSTOMER_TRX_LINES_ALL RCTL_SS,
        apps.ra_customer_trx_all rta_ss,
        apps.pa_projects_all ppa,
        apps.pa_project_customers_v pv,
        apps.hz_cust_acct_sites_all bcas,
        apps.hz_party_sites bhps,
        apps.hz_locations bhl,
        APPS.HZ_CUST_ACCT_SITES_ALL SCAS,
        apps.hz_party_sites shps,
        apps.hz_locations shl,
        apps.pa_project_contacts_v pacv,
        apps.hr_operating_units hou,
        apps.ra_terms_tl rt
      WHERE 1                               = 1
      AND ppa.segment1                      = rctl_ss.interface_line_attribute1
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
      AND RTA_Ss.CUSTOMER_TRX_ID            = RCTL_Ss.CUSTOMER_TRX_ID
      AND RTA_SS.ORG_ID                     = HOU.ORGANIZATION_ID
      AND rta_ss.term_id                    = rt.term_id
      AND rt.language                       = 'US'
      AND line_type                        <> 'TAX'
      AND RTA_SS.TRX_NUMBER=P_INVOICE_ID
      AND hou.name=P_ORG_NAME;

cursor c4_inv_narrative(P_ORG_NAME varchar2, P_INVOICE_ID varchar2)
is
SELECT DECODE (
        (SELECT NVL (stg.trans_type, 'EVENT') FROM apps.pa_draft_invoices_all ph,
          apps.pa_draft_invoice_lines_v pl,
          apps.ttec_bill_evnt_tsk_stg stg WHERE pl.project_id = ph.project_id
        AND ph.draft_invoice_num                              = pl.draft_invoice_num
        AND STG.EVENT_ID(+)                                   = PL.EVENT_ID
        AND PL.LINE_NUM                                       = RCTL_Ss.INTERFACE_LINE_ATTRIBUTE6
        AND PH.RA_INVOICE_NUMBER                              = RTA_SS.TRX_NUMBER
        AND PH.SYSTEM_REFERENCE                               = RCTL_Ss.CUSTOMER_TRX_ID
        ), 'EVENT', RCTL_SS.DESCRIPTION
        ||'|'||' Dates : '
        ||
        (SELECT NVL (stg.invoice_start_date
          || ' to '
          ||stg.invoice_start_date, NULL)
        FROM apps.pa_draft_invoices_all ph,
          apps.pa_draft_invoice_lines_v pl,
          apps.ttec_bill_evnt_tsk_stg stg
        WHERE pl.project_id      = ph.project_id
        AND ph.draft_invoice_num = pl.draft_invoice_num
       AND stg.event_id(+)      = pl.event_id
        AND PL.LINE_NUM          = RCTL_Ss.INTERFACE_LINE_ATTRIBUTE6
        AND PH.RA_INVOICE_NUMBER = RTA_Ss.TRX_NUMBER
        AND PH.SYSTEM_REFERENCE  = RCTL_Ss.CUSTOMER_TRX_ID
        )
        || '|'||' Fees: '
        ||revenue_amount, NULL ) inv_narrative, RTA_Ss.TRX_NUMBER, hou.name
      FROM APPS.RA_CUSTOMER_TRX_LINES_ALL RCTL_SS,
        apps.ra_customer_trx_all rta_ss,
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
        apps.ra_terms_tl rt
      WHERE 1                               = 1
      AND ppa.segment1                      = rctl_ss.interface_line_attribute1
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
      AND RTA_Ss.CUSTOMER_TRX_ID            = RCTL_Ss.CUSTOMER_TRX_ID
      AND RTA_SS.ORG_ID                     = HOU.ORGANIZATION_ID
      AND rta_ss.term_id                    = rt.term_id
      AND rt.language                       = 'US'
      AND line_type                        <> 'TAX'
      AND RTA_SS.TRX_NUMBER=P_INVOICE_ID
      AND hou.name=P_ORG_NAME;

l_xmloutput clob;
l_invoice_id varchar2(100);
l_special_instruction clob;
l_Inv_Exp_Narrative clob;
l_Inv_Narrative clob;
l_update_status boolean;
 BEGIN
 fnd_file.put_line(fnd_file.output,'<?xml version="1.0" encoding="US-ASCII" standalone="no"?>');
 fnd_file.put_line (fnd_file.output,'<mailMergeData>');
for c1_rec in c1(P_INVOICE_NUM,P_ORG_NAME,P_PRINT_PENDING,P_TEMPLATE)
loop
fnd_file.put_line (fnd_file.output,'<G_MAIL_MERGE>');
fnd_file.put_line (fnd_file.output,'<INV_ID>'|| dbms_xmlgen.convert(c1_rec.InvoiceID)|| '</INV_ID>');
fnd_file.put_line (fnd_file.output, '<BU_CODE>'|| dbms_xmlgen.convert(c1_rec.BUCode)|| '</BU_CODE>');
fnd_file.put_line (fnd_file.output, '<FIRST>'|| dbms_xmlgen.convert(c1_rec.InvoiceContactFirstName)|| '</FIRST>');
fnd_file.put_line (fnd_file.output, '<LAST>'|| dbms_xmlgen.convert(c1_rec.InvoiceContactLastName)|| '</LAST>');
fnd_file.put_line (fnd_file.output, '<POSITION>'|| dbms_xmlgen.convert(c1_rec.InvoiceContactPosition)|| '</POSITION>');
fnd_file.put_line (fnd_file.output, '<ADDRESS>'|| dbms_xmlgen.convert(c1_rec.InvoiceContactAddressee)|| '</ADDRESS>');
fnd_file.put_line (fnd_file.output, '<ADDRESS1>'|| dbms_xmlgen.convert(c1_rec.InvoiceContactAddress1)|| '</ADDRESS1>');
fnd_file.put_line (fnd_file.output,  '<ADDRESS2>'|| dbms_xmlgen.convert(c1_rec.InvoiceContactAddress2)|| '</ADDRESS2>');
fnd_file.put_line (fnd_file.output,'<CITY>'|| dbms_xmlgen.convert(c1_rec.InvoiceContactAddressCity)|| '</CITY>');
fnd_file.put_line (fnd_file.output,'<STATE>'|| dbms_xmlgen.convert(c1_rec.InvoiceContactAddressState)|| '</STATE>');
fnd_file.put_line (fnd_file.output, '<PO>'|| dbms_xmlgen.convert(c1_rec.InvoiceContactAddressPostcode)|| '</PO>');
fnd_file.put_line (fnd_file.output, '<COUNTRY>'|| dbms_xmlgen.convert(c1_rec.InvoiceContactAddressCountry)|| '</COUNTRY>');
fnd_file.put_line (fnd_file.output, '<PONUM>'|| dbms_xmlgen.convert(c1_rec.InvClientPONumber)|| '</PONUM>');
fnd_file.put_line (fnd_file.output, '<INVDATE>'|| dbms_xmlgen.convert(c1_rec.InvDate)|| '</INVDATE>');
fnd_file.put_line (fnd_file.output,'<TAXDESC>'|| dbms_xmlgen.convert(c1_rec.TaxDescription)|| '</TAXDESC>');
l_Inv_Narrative :='';
for c4_inv_narrative_rec in c4_inv_narrative(P_ORG_NAME,c1_rec.InvoiceID)
loop
if l_Inv_Narrative='' or l_Inv_Narrative is null then
  if c4_inv_narrative_rec.inv_narrative is not null then
    l_Inv_Narrative := c4_inv_narrative_rec.inv_narrative;
  end if;
else
l_Inv_Narrative := l_Inv_Narrative ||'|'||c4_inv_narrative_rec.inv_narrative;
end if;
end loop;
fnd_file.put_line (fnd_file.output, '<EXP_NARRATIVE>'|| dbms_xmlgen.convert(l_Inv_Exp_Narrative)|| '</EXP_NARRATIVE>');
fnd_file.put_line (fnd_file.output, '<NARRATIVE>'|| dbms_xmlgen.convert(l_Inv_Narrative)|| '</NARRATIVE>');
--l_xmloutput := l_xmloutput || '<EXP_NARRATIVE>'|| c1_rec.InvExpNarrative|| '</EXP_NARRATIVE>';
l_Inv_Exp_Narrative :='';
for c2_inv_exp_narrative_rec in c2_inv_exp_narrative(P_ORG_NAME,c1_rec.InvoiceID)
loop
if l_Inv_Exp_Narrative='' OR l_Inv_Exp_Narrative is null then
if c2_inv_exp_narrative_rec.inv_exp_narrative is not null then
l_Inv_Exp_Narrative := c2_inv_exp_narrative_rec.inv_exp_narrative;
end if;
else
l_Inv_Exp_Narrative := l_Inv_Exp_Narrative ||'|'||c2_inv_exp_narrative_rec.inv_exp_narrative;
end if;
end loop;
fnd_file.put_line (fnd_file.output, '<EXP_NARRATIVE>'|| dbms_xmlgen.convert(l_Inv_Exp_Narrative)|| '</EXP_NARRATIVE>');
fnd_file.put_line (fnd_file.output, '<INV_ONLINE>'|| dbms_xmlgen.convert(c1_rec.InvOnlineNarrative)|| '</INV_ONLINE>');
l_special_instruction :='';
for c3_special_instruction_rec in c3_special_instruction(P_ORG_NAME,c1_rec.InvoiceID)
loop
if l_special_instruction='' or l_special_instruction is null then
if c3_special_instruction_rec.special_instruction is not null then
l_special_instruction := c3_special_instruction_rec.special_instruction;
end if;
else
l_special_instruction := l_special_instruction ||'|'||c3_special_instruction_rec.special_instruction;
end if;
end loop;
fnd_file.put_line (fnd_file.output, '<SPECIAL_INSTR>'|| dbms_xmlgen.convert(l_special_instruction)|| '</SPECIAL_INSTR>');
fnd_file.put_line (fnd_file.output, '<CCODE>'|| dbms_xmlgen.convert(c1_rec.CCYCode)|| '</CCODE>');

fnd_file.put_line (fnd_file.output, '<TYPE>'|| dbms_xmlgen.convert(c1_rec.ProgramType)|| '</TYPE>');
fnd_file.put_line (fnd_file.output, '<ID>'|| dbms_xmlgen.convert(c1_rec.ProgramID)|| '</ID>');
fnd_file.put_line (fnd_file.output, '<EXTAX>'|| dbms_xmlgen.convert(c1_rec.InvFeesExTax)|| '</EXTAX>');
fnd_file.put_line (fnd_file.output, '<EXPEXTAX>'|| dbms_xmlgen.convert(c1_rec.InvTaxExpnsExTax)|| '</EXPEXTAX>');
fnd_file.put_line (fnd_file.output, '<NOEXPTAX>'|| dbms_xmlgen.convert(c1_rec.InvNoTaxExpns)|| '</NOEXPTAX>');
fnd_file.put_line (fnd_file.output, '<TOTALEXTAX>'|| dbms_xmlgen.convert(c1_rec.InvTotalExTax)|| '</TOTALEXTAX>');
fnd_file.put_line (fnd_file.output, '<TAX_AMOUNT>'|| dbms_xmlgen.convert(c1_rec.InvTaxAmount)|| '</TAX_AMOUNT>');
fnd_file.put_line (fnd_file.output, '<TOTAL_TAX>'|| dbms_xmlgen.convert(c1_rec.InvTotalIncTax)|| '</TOTAL_TAX>');
fnd_file.put_line (fnd_file.output, '<INV_NUMBER>'|| dbms_xmlgen.convert(c1_rec.InvoiceNumber)|| '</INV_NUMBER>');
fnd_file.put_line (fnd_file.output, '<METHOD>'|| dbms_xmlgen.convert(c1_rec.PaymentMethod)|| '</METHOD>');
fnd_file.put_line (fnd_file.output, '<CLIENT>'|| dbms_xmlgen.convert(c1_rec.ClientID)|| '</CLIENT>');
fnd_file.put_line (fnd_file.output, '<GPO>'|| dbms_xmlgen.convert(c1_rec.GPOffice)|| '</GPO>');
fnd_file.put_line (fnd_file.output, '<template_name>'|| dbms_xmlgen.convert(c1_rec.template_name)|| '</template_name>');
--fnd_file.put_line (fnd_file.output,c1_rec.InvoiceID); --c1_rec.InvoiceID);
fnd_file.put_line (fnd_file.output,'</G_MAIL_MERGE>');
end loop;
fnd_file.put_line (fnd_file.output,'</mailMergeData>');

l_update_status:=  TTEC_MAIL_MER_TRIGGER_PACKAGE.afterReportTrigger(P_ORG_NAME,P_TEMPLATE,P_INVOICE_NUM, P_PRINT_PENDING);
END;


END;
/
show errors;
/