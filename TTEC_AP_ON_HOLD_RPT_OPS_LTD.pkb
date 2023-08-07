create or replace PACKAGE BODY TTEC_AP_ON_HOLD_RPT_OPS_LTD AS
--
-- Program Name:  TTEC_AP_ON_HOLD_RPT_OPS_LTD
-- Description:  This program generates AP On Hold Report for Operations - Limited
--  this is a copy of the program TTEC_AP_ON_HOLD_RPT_OPS and it eliminates two set of books
--
-- Input/Output Parameters:
--
--
--
-- Tables Modified:  N/A
--
--
-- Created By:  Christiane Chan
-- Date: Feb 6, 2008
--
--
-- Modification Log:
-- Developer    VERSION       Date        Description
-- ----------   -------      --------    ---------------------------------------------------------------------
-- C. Chan       1.0         09/30/2009   WO#621035 - Please modify to have the hold codes concatenated and
--                                                    remove any restrictions on the hold code
--                                        WO#632387 - We would like to modify the report to run across all
--                                                    sets of books, not just the one you're in.
--                                                    The same set of people are getting the output so a lot
--                                                    of setup and combining of files work going on
-- J. Masters    2.0        04/23/10      Request#29932 - NEW MODIFICATIONS / REQUIREMENTS:
--                                           1. Remove the Subtotals � this interferes with Excel filtering and Pivot Tables
--                                           2. Reposition the Columns � this allows for the analyst to read the data from
--                                              left to right without shuffling back and forth through the columns
--                                           3. Include the Invoice Due Date
--                                           4. Custom Sort
--                                               a. Set of Books
--                                               b. Vendor Name
--                                               c. Vendor Site Code
--                                               d. Inv Due Date
--                                               e. Invoice Number
--                                           5. The last column is Unknown?? Where is this data coming from??
--                                           6. Include Last_Updated_By
--
-- C. Chan       3.0         11/13/2013   R#1830357 - Fixed for AP - Columns of data not displaying for companies other than US
-- K.Deebak      4.0         1/28/2014    Added 2 new columns NAME(PROJECT_NAME), TASK_NAME for the report output
--IXPRAVEEN(ARGANO)      1.0     11-May-2023     R12.2 Upgrade Remediation
-- Global Variables ---------------------------------------------------------------------------------


PROCEDURE Print_Line(ap_rec c_detail_record%ROWTYPE) IS

cursor c_preparer(po_numbers VARCHAR2) is
select DISTINCT reqh.SEGMENT1 req_no,
PO_INQ_SV.GET_PERSON_NAME(rl.to_person_ID) requestor,
rl.to_person_ID,
PO_INQ_SV.GET_PERSON_NAME(reqh.preparer_ID) preparer
from po_headers_all po
    ,po_distributions_all pod
    ,po_requisition_lines_all rl
    ,PO_REQUISITION_HEADERS_ALL REQH
    ,po_req_distributions rd
where  po.segment1 in ( select po_numbers
                        FROM   ap_holds_v h
                        where   h.INVOICE_ID  = v_invoice_id
                        and po_numbers is not null
                      )
and po.po_header_id = pod.po_header_id
and pod.req_distribution_id = rd.distribution_id
and  reqh.REQUISITION_HEADER_ID = rl.REQUISITION_HEADER_ID
and rd.REQUISITION_LINE_ID = rl.REQUISITION_LINE_ID;


cursor c_requestor_sup is
SELECT papf1.full_name Requestor_Supervisor,
       j.name Supervisor_job_title
FROM   per_all_assignments_f paaf,
       per_all_assignments_f paaf2 ,
       per_all_people_f papf1,
       --hr.per_jobs j				-- Commented code by IXPRAVEEN-ARGANO,11-May-2023
       apps.per_jobs j              --  code Added by IXPRAVEEN-ARGANO,   11-May-2023
WHERE  paaf.supervisor_id = papf1.person_id
and    papf1.person_id = paaf2.person_id
and    paaf2.job_id = j.job_id
and    paaf.effective_start_date = (select MAX(paaf3.effective_start_date)
                                    from per_all_assignments_f paaf3
                                    where paaf3.person_id = paaf.person_id
                                    and paaf3.effective_start_date <= TRUNC(SYSDATE)) -- asg of requestor
and    paaf.effective_start_date BETWEEN paaf2.effective_start_date AND paaf2.effective_end_date   -- asg supervisor
and    paaf.effective_start_date BETWEEN papf1.effective_start_date AND papf1.effective_end_date -- person supervisor
--and    v_inv_date BETWEEN paaf.effective_start_date AND paaf.effective_end_date
--and    v_inv_date BETWEEN paaf2.effective_start_date AND paaf2.effective_end_date
--and    v_inv_date BETWEEN papf1.effective_start_date AND papf1.effective_end_date
and    paaf.person_id = v_requestor_id;

BEGIN

      v_inv_date   := ap_rec.inv_date;
      v_preparer  := '';
      v_requestor := '';
      v_requestor_id := NULL;
      v_requestor_supervisor := '';
      v_supervisor_job_title := '';

      if v_po_numbers is not null then

        v_seperator  := '';
        v_seperator2 := '';
        v_seperator3 := '';
        l_stage:= 'preparer_rec';
        for prep_rec in c_preparer(v_po_numbers) loop
         v_preparer := v_preparer ||v_seperator||REPLACE(prep_rec.preparer,',',' ')||' (Req.No:'||REPLACE(prep_rec.req_no,',',' ')||')';
         v_seperator := ' / ';
         if prep_rec.to_person_id is not null then
            v_requestor_id := prep_rec.to_person_id;
            v_requestor := v_requestor ||v_seperator2||REPLACE(prep_rec.requestor,',',' ')||' (Req.No:'||REPLACE(prep_rec.req_no,',',' ')||')';
             v_seperator2 := ' / ';

             l_stage:= 'supervisor_rec';
             if v_requestor_id is not null then
                for sup_rec in c_requestor_sup loop
                 -- v_requestor_supervisor := sup_rec.Requestor_Supervisor;
                  v_requestor_supervisor := v_requestor_supervisor ||v_seperator3||REPLACE(sup_rec.Requestor_Supervisor,',',' ')||' (Req.No:'||REPLACE(prep_rec.req_no,',',' ')||')';
                  --v_supervisor_job_title := sup_rec.supervisor_job_title;
                  v_supervisor_job_title := v_supervisor_job_title ||v_seperator3||REPLACE(sup_rec.supervisor_job_title,',',' ')||' (Req.No:'||REPLACE(prep_rec.req_no,',',' ')||')';
                  v_seperator3 := ' / ';
                end loop;
             end if;
         end if;
        end loop;
      end if;

      l_stage:= 'After hold_rec';
     l_rec :=  ap_rec.SET_OF_BOOKS
        ||','||REPLACE(ap_rec.VENDOR_NAME,',',' ')
        ||','||ap_rec.VENDOR_SITE_CODE        -- Version 1.0
        ||','||ap_rec.DUE_DATE                --2.0
        ||','||ap_rec.INV_NO
        ||','||ap_rec.LOCATION
        ||','||REPLACE(ap_rec.LOCATION_DESC,',',' ')
        ||','||ap_rec.CLIENT
        ||','||ap_rec.DEPARTMENT
        ||','||ap_rec.ACCOUNT
        ||','||ap_rec.AMT
        ||','||ap_rec.CURRENCY
        ||','||ap_rec.INV_DATE
        ||','||ap_rec.INV_AMT
        ||','||ap_rec.ENTERED_DATE
        ||','||ap_rec.DAYS_PAST_DUE
        ||','||ap_rec.POSTED_FLAG            -- Version 1.0
        ||','||REPLACE(ap_rec.INV_DESC,',',' ')
        ||','||REPLACE(REPLACE(ap_rec.PO_NUMBERS,',',' '),'''','')
        ||','||REPLACE(v_preparer,',',' ')
        ||','||REPLACE(V_REQUESTOR,',',' ')
        ||','||REPLACE(V_REQUESTOR_SUPERVISOR,',',' ')
        ||','||REPLACE(V_SUPERVISOR_JOB_TITLE,',',' ')
        ||','||v_SHIPMENT_ORDERED
        ||','||v_SHIPMENT_BILLED
        ||','||v_SHIPMENT_RECEIVED
        ||','||ap_rec.HOLD_CODE
        ||','||ap_rec.PROJECT_NAME   -- Version 4.0
		||','||ap_rec.TASK_NAME      -- Version 4.0
       -- ||','||REPLACE(ap_rec.HOLD_REASON,',',' ') -- Version 1.0
        ||','||ap_rec.description               --2.0
        ;

        apps.fnd_file.put_line(apps.fnd_file.output,l_rec);

END;
PROCEDURE main(errcode varchar2, errbuff varchar2, p_sob number ) IS

--  Program to write out AP On Hold Report for General Accounting per GL Department specifications
--
-- Created By:  Christiane Chan
-- Date: Feb 6, 2008
--
-- Filehandle Variables
--
BEGIN
      IF p_sob is not null THEN
         select name
         into v_sob_name
         from gl_sets_of_books
         where SET_OF_BOOKS_ID = p_sob;
      ELSE
         v_sob_name := 'All';
      END IF;
        Fnd_File.put_line(Fnd_File.LOG, '******************************************');
      Fnd_File.put_line(Fnd_File.LOG,   'Program Name:  TTEC_AP_ON_HOLD_RPT_OPS_LTD' );
      Fnd_File.put_line(Fnd_File.LOG,   '******************************************');
      l_rec := '=======================================================';
        apps.fnd_file.put_line(apps.fnd_file.output,l_rec);
      l_rec := 'TeleTech AP Invoice On Hold Report - LDT - Operations';
        apps.fnd_file.put_line(apps.fnd_file.output,l_rec);
      l_rec := '=======================================================';
        apps.fnd_file.put_line(apps.fnd_file.output,l_rec);
      l_rec := 'Report Date: ' || to_char(SYSDATE,'DD-MON-YYYY HH24:MI:SS');
        apps.fnd_file.put_line(apps.fnd_file.output,l_rec);
      l_rec := 'Set Of Book(s): '|| v_sob_name;
        apps.fnd_file.put_line(apps.fnd_file.output,l_rec);
--      l_rec := 'AP Invoice On Hold since GL Date: '|| to_char(SYSDATE - 186,'DD-MON-YYYY');
--        apps.fnd_file.put_line(apps.fnd_file.output,l_rec);
      l_rec := ' ';
        apps.fnd_file.put_line(apps.fnd_file.output,l_rec);

      l_stage:= 'Title';

      l_rec :=  'SET OF BOOKS'
         ||','||'VENDOR NAME'
         ||','||'VENDOR SITE CODE'        -- Version 1.0
         ||','||'INVOICE DUE DATE'        --2.0
         ||','||'INVOICE NUMBER'
         ||','||'LOCATION DESCRIPTION'
         ||','||'LOCATION'
         ||','||'CLIENT'
         ||','||'DEPARTMENT'
         ||','||'ACCOUNT'
         ||','||'DISTRIBUTION AMT'
         ||','||'CURRENCY'
         ||','||'INVOICE DATE'
         ||','||'INVOICE AMT'
         ||','||'GL DATE'
         ||','||'TOTAL AGED FROM GL DATE'
         ||','||'POSTED IN GL' -- Version 1.0
         ||','||'DESCRIPTION'
         ||','||'PO NUMBERS'
         ||','||'REQUISITION PREPARED BY'
         ||','||'REQUESTOR'
         ||','||'REQUESTOR SUPERVISOR'
         ||','||'SUPERVISOR JOB TITLE'
         ||','||'SHIPMENT_ORDERED'
         ||','||'SHIPMENT_BILLED'
         ||','||'SHIPMENT_RECEIVED'
         ||','||'HOLD CODE'
         ||','||'PROJECT NAME'	-- Version 4.0
         ||','||'TASK NAME'		-- Version 4.0
--         ||','||'HOLD REASON' -- Version 1.0
         ||','||'LAST_UPDATE_BY';       --2.0


     apps.fnd_file.put_line(apps.fnd_file.output,l_rec);

     l_stage:= 'ap_rec';

     v_sob := p_sob;

     OPEN c_detail_record;

     LOOP
     FETCH c_detail_record INTO v_ap_rec;
     EXIT WHEN c_detail_record%NOTFOUND;
      v_invoice_id := v_ap_rec.INV_ID;
      v_org_id     := v_ap_rec.ORG_ID;
      v_po_numbers := v_ap_rec.PO_NUMBERS;

      v_SHIPMENT_ORDERED  :=  NULL;
      v_SHIPMENT_BILLED   :=  NULL;
      v_SHIPMENT_RECEIVED :=  NULL;
      v_hold_found        :=  FALSE;

      --fnd_client_info.set_org_context(v_org_id); /* V 3.0 */
      MO_GLOBAL.SET_POLICY_CONTEXT('S',v_org_id); /* V 3.0 */

      l_stage:= 'hold_rec';

      FOR v_shipment_rec in c_holds
      Loop
          v_SHIPMENT_ORDERED  :=  v_shipment_rec.SHIPMENT_ORDERED;
          v_SHIPMENT_BILLED   :=  v_shipment_rec.SHIPMENT_BILLED;
          v_SHIPMENT_RECEIVED :=  v_shipment_rec.SHIPMENT_RECEIVED;
          v_hold_found        :=  TRUE;

          print_line(v_ap_rec);

      End Loop; /* hold_rec */

      IF  NOT v_hold_found
      THEN
          l_stage:= 'hold_rec2';

          FOR v_shipment_rec2 in c_holds2
          Loop
              v_SHIPMENT_ORDERED  :=  v_shipment_rec2.SHIPMENT_ORDERED;
              v_SHIPMENT_BILLED   :=  v_shipment_rec2.SHIPMENT_BILLED;
              v_SHIPMENT_RECEIVED :=  v_shipment_rec2.SHIPMENT_RECEIVED;

              print_line(v_ap_rec);

          End Loop; /* hold_rec */

      END IF;




     End Loop; /* ap rec */

     CLOSE c_detail_record;
/*
      l_rec := ' ';
        apps.fnd_file.put_line(apps.fnd_file.output,l_rec);
      l_rec := '=========================================';
        apps.fnd_file.put_line(apps.fnd_file.output,l_rec);
      l_rec := 'Subtotal By Set Of Book(s) and Currencies';
        apps.fnd_file.put_line(apps.fnd_file.output,l_rec);
      l_rec := '=========================================';
        apps.fnd_file.put_line(apps.fnd_file.output,l_rec);
      l_rec := ' ';
        apps.fnd_file.put_line(apps.fnd_file.output,l_rec);

      l_rec :=  'SET OF BOOKS'
         ||','||'CURRENCY'
         ||','||'TOTAL DISTRIBUTION AMT';

        apps.fnd_file.put_line(apps.fnd_file.output,l_rec);

*/
        --2.0

--      For ap_summary_rec in c_summary_by_sob loop


--        -------------------------------------------------------------------------------------------------------------------------

--        --
--       --
--       --  Fnd_File.put_line(Fnd_File.LOG, '7');

--      -- l_rec := '10'||'-'||nvl(replace(replace(to_char(pos_pay.amount,'S000000000.00'),'+','0'),'.',''),lpad('0',12,'0'))||substr(pos_pay.description, 1, 15)||lpad ( ' ', 69, ' ')||'01'||lpad(' ', 117,' ');

--      l_rec :=  ap_summary_rec.SET_OF_BOOKS
--        ||','||ap_summary_rec.CURRENCY
--        ||','||ap_summary_rec.TOT_AMT;

--        apps.fnd_file.put_line(apps.fnd_file.output,l_rec);


--     End Loop; /* ap summary */   --2.0

      Fnd_File.put_line(Fnd_File.LOG, '**********************************');


EXCEPTION
    WHEN OTHERS THEN

        Fnd_File.put_line(Fnd_File.LOG,'Operation fails on '||l_stage);

        l_msg := SQLERRM;
        Fnd_File.put_line(Fnd_File.LOG,'Exception OTHERS in TTEC_AP_ON_HOLD_RPT_OPS: '||l_msg);

        RAISE_APPLICATION_ERROR(-20003,'Exception OTHERS in TTEC_AP_ON_HOLD_RPT_OPS: '||l_msg);

END main;

END TTEC_AP_ON_HOLD_RPT_OPS_LTD;
/
show errors;
/