create or replace PACKAGE BODY PO_REQAPPROVAL_TTEC1 AS
/* $Header: POXWPA1B.pls 115.98.1158.4 2003/04/03 09:14:08 rramasam ship $ */

 /*=======================================================================+
 | FILENAME
 |   POXWPA1B.pls
 |
 | DESCRIPTION
 |   PL/SQL body for package:  PO_REQAPPROVAL_INIT1
 |
 | NOTES        Ben Chihaoui Created 6/15/97
 | MODIFIED    (MM/DD/YY)
 | davidng      06/04/2002      Fix for bug 2401183. Used the Workflow Utility
 |                              Package wrapper function and procedure to get
 |                              and set attributes REL_NUM and REL_NUM_DASH
 |                              in procedure PO_REQAPPROVAL_INIT1.Initialise_Error
   IXPRAVEEN(ARGANO)            1.0     18-july-2023     R12.2 Upgrade Remediation
 *=======================================================================*/
--


/*****************************************************************************
* The following are local/Private procedure that support the workflow APIs:  *
*****************************************************************************/

--
-- TTEC changed to add a passingof l_orgid
PROCEDURE   PrintDocument(itemtype varchar2,itemkey varchar2, l_orgid number);




FUNCTION Print_Requisition(p_doc_num varchar2, p_qty_precision varchar,
                           p_user_id varchar2) RETURN number ;

FUNCTION Print_PO(p_doc_num varchar2, p_qty_precision varchar,
                  p_user_id varchar2, l_orgid number) RETURN number ;



FUNCTION Print_Release(p_doc_num varchar2, p_qty_precision varchar,
             p_release_num varchar2, p_user_id varchar2) RETURN number ;



/**************************************************************************************
* The following are the global APIs.						      *
**************************************************************************************/


procedure Print_Doc_Yes_No(   itemtype        in varchar2,
                              itemkey         in varchar2,
                              actid           in number,
                              funcmode        in varchar2,
                              resultout       out varchar2    )  is
l_orgid       number;
l_print_doc   varchar2(2);
x_progress    varchar2(300);

l_doc_string varchar2(200);
l_preparer_user_name varchar2(100);

BEGIN
  x_progress := 'PO_REQAPPROVAL_INIT1.Print_Doc_Yes_No: 01';
  /* DEBUG */  PO_WF_DEBUG_PKG.insert_debug(itemtype,itemkey,x_progress);


  -- Do nothing in cancel or timeout mode
  --
  if (funcmode <> wf_engine.eng_run) then

      resultout := wf_engine.eng_null;
      return;

  end if;

  l_print_doc := wf_engine.GetItemAttrText (itemtype => itemtype,
                                         itemkey  => itemkey,
                                         aname    => 'PRINT_DOCUMENT');

  /* the value of l_print_doc should be Y or N */
  IF (nvl(l_print_doc,'N') <> 'Y') THEN
	l_print_doc := 'N';
  END IF;

  --
        resultout := wf_engine.eng_completed || ':' || l_print_doc ;
  --
  x_progress := 'PO_REQAPPROVAL_INIT1.Print_Doc_Yes_No: 02. Result= ' || l_print_doc;
  /* DEBUG */  PO_WF_DEBUG_PKG.insert_debug(itemtype,itemkey,x_progress);

EXCEPTION
  WHEN OTHERS THEN
    l_doc_string := PO_REQAPPROVAL_INIT1.get_error_doc(itemType, itemkey);
    l_preparer_user_name := PO_REQAPPROVAL_INIT1.get_preparer_user_name(itemType, itemkey);
    wf_core.context('PO_REQAPPROVAL_INIT1.Print_Doc_Yes_No',x_progress);
    PO_REQAPPROVAL_INIT1.send_error_notif(itemType, itemkey, l_preparer_user_name, l_doc_string, sqlerrm, 'PO_REQAPPROVAL_INIT1.PRINT_DOC_YES_NO');
    raise;

END Print_Doc_Yes_No;


-- Print_Document, main entry point,
-- Just changed name for TTEC
--   Resultout
--     ACTIVITY_PERFORMED
--   Print Document.  This is main entry point to the
-- routine,

procedure Print_Document_ttec (   itemtype        in varchar2,
                            itemkey         in varchar2,
                            actid           in number,
                            funcmode        in varchar2,
                            resultout       out varchar2    ) is
l_orgid       number;
l_print_doc   varchar2(2);
x_progress    varchar2(300);

l_doc_string varchar2(200);
l_preparer_user_name varchar2(100);

BEGIN
  x_progress := 'PO_REQAPPROVAL_INIT1.Print_Document: 01';
  /* DEBUG */  PO_WF_DEBUG_PKG.insert_debug(itemtype,itemkey,x_progress);


  -- Do nothing in cancel or timeout mode
  --
  if (funcmode <> wf_engine.eng_run) then

      resultout := wf_engine.eng_null;
      return;

  end if;

  l_orgid := wf_engine.GetItemAttrNumber (itemtype => itemtype,
                                         itemkey  => itemkey,
                                         aname    => 'ORG_ID');

  IF l_orgid is NOT NULL THEN

    fnd_client_info.set_org_context(to_char(l_orgid));

  END IF;

  x_progress := 'PO_REQAPPROVAL_INIT1.Print_Document: 02';

  PrintDocument(itemtype,itemkey, l_orgid);
  --
     resultout := wf_engine.eng_completed || ':' || 'ACTIVITY_PERFORMED' ;
  --
  x_progress := 'PO_REQAPPROVAL_INIT1.Print_Document: 03';

EXCEPTION
  WHEN OTHERS THEN
    l_doc_string := PO_REQAPPROVAL_INIT1.get_error_doc(itemType, itemkey);
    l_preparer_user_name := PO_REQAPPROVAL_INIT1.get_preparer_user_name(itemType, itemkey);
    wf_core.context('PO_REQAPPROVAL_INIT1.Print_Document',x_progress);
    PO_REQAPPROVAL_INIT1.send_error_notif(itemType, itemkey, l_preparer_user_name, l_doc_string, sqlerrm, 'PO_REQAPPROVAL_INIT1.PRINT_DOCUMENT');
    raise;

END Print_Document_TTEC;

-- Dummy
-- IN
--   itemtype  --   itemkey  --   actid   --   funcmode
-- OUT
--   Resultout
--      Activity Performed
-- Dummy procedure that does nothing (NOOP). Used to set the
-- cost above the backgound engine threshold. This causes the
-- workflow to execute in the background.
procedure Dummy(   itemtype        in varchar2,
                            itemkey         in varchar2,
                            actid           in number,
                            funcmode        in varchar2,
                            resultout       out varchar2    ) is

BEGIN

  /* Do nothing */
  NULL;

END Dummy;


/*****************************************************************************
*
*  Supporting APIs declared in the package spec.
*****************************************************************************/


PROCEDURE get_multiorg_context(document_type varchar2, document_id number,
                               x_orgid IN OUT number) is

cursor get_req_orgid is
  select org_id
  from po_requisition_headers_all
  where requisition_header_id = document_id;

cursor get_po_orgid is
  select org_id
  from po_headers_all
  where po_header_id = document_id;

cursor get_release_orgid is
  select org_id
  from po_releases_all
  where po_release_id = document_id;



x_progress varchar2(3):= '000';

BEGIN

  x_progress := '001';
  IF document_type = 'REQUISITION' THEN


     OPEN get_req_orgid;
     FETCH get_req_orgid into x_orgid;
     CLOSE get_req_orgid;

  ELSIF document_type IN ( 'PO','PA' ) THEN

     OPEN get_po_orgid;
     FETCH get_po_orgid into x_orgid;
     CLOSE get_po_orgid;

  ELSIF document_type = 'RELEASE' THEN

     OPEN get_release_orgid ;
     FETCH get_release_orgid into x_orgid;
     CLOSE get_release_orgid;

  END IF;

EXCEPTION
  WHEN OTHERS THEN
    wf_core.context('PO_REQAPPROVAL_INIT1','get_multiorg_context',x_progress);
        raise;

END get_multiorg_context;


--
PROCEDURE get_employee_id(p_username IN varchar2, x_employee_id OUT number) is

-- DEBUG: Is this the best way to get the emp_id of the username
--        entered as a forward-to in the notification?????
--
  /* 1578061 add orig system condition to enhance performance. */

  cursor c_empid is
    select ORIG_SYSTEM_ID
    from   wf_users WF
    where  WF.name     = p_username
      and  ORIG_SYSTEM NOT IN ('HZ_PARTY', 'POS', 'ENG_LIST', 'CUST_CONT');

x_progress varchar2(3):= '000';

BEGIN

    open  c_empid;
    fetch c_empid into x_employee_id;

    /* DEBUG: get Vance and Kevin opinion on this:
    ** If no employee_id is found then return null. We will
    ** treat that as the user not supplying a forward-to username.
    */
    IF c_empid%NOTFOUND  THEN

       x_employee_id := NULL;

    END IF;

    close c_empid;

EXCEPTION
  WHEN OTHERS THEN
    wf_core.context('PO_REQAPPROVAL_INIT1','get_employee_id',p_username);
        raise;


END get_employee_id;
--
-- TTEC changed to add to pass org Id
-- This routine used to print one report, TTEC changed it to look at the or_id
-- then based on the org id select a name of the Graphics report to print.
-- The report names are stored in the database in table  cust.ttec_po_printprogram
--
PROCEDURE   PrintDocument(itemtype varchar2,itemkey varchar2, l_orgid number) is

l_document_type   VARCHAR2(25);
l_document_num   VARCHAR2(30);
l_release_num     NUMBER;
l_request_id      NUMBER := 0;
l_qty_precision   VARCHAR2(30);
l_user_id         VARCHAR2(30);

x_progress varchar2(200);

BEGIN

  x_progress := 'PO_REQAPPROVAL_INIT1.PrintDocument: 01';
  /* DEBUG */  PO_WF_DEBUG_PKG.insert_debug(itemtype,itemkey,x_progress);

   -- Get the profile option report_quantity_precision

   fnd_profile.get('REPORT_QUANTITY_PRECISION', l_qty_precision);

   /* Bug 2012896: the profile option REPORT_QUANTITY_PRECISION could be
      NULL. Even at site level!  And in that case the printing of report
      results into the inappropriate printing of quantities.
      Fix: Now, if the profile option is NULL, we are setting the variable
      l_qty_precision to 2, so that the printing would not fail. Why 2 ?
      This is the default defined in the definition of the said profile
      option. */

   IF l_qty_precision IS NULL THEN
      l_qty_precision := '2';
   END IF;

   -- Get the user id for the current user.  This information
   -- is used when sending concurrent request.

   FND_PROFILE.GET('USER_ID', l_user_id);

   -- Send the concurrent request to print document.

  l_document_type := wf_engine.GetItemAttrText (itemtype => itemtype,
                                         itemkey  => itemkey,
                                         aname    => 'DOCUMENT_TYPE');

  l_document_num := wf_engine.GetItemAttrText (itemtype => itemtype,
                                         itemkey  => itemkey,
                                         aname    => 'DOCUMENT_NUMBER');

   IF l_document_type = 'REQUISITION' THEN

        l_request_id := Print_Requisition(l_document_num, l_qty_precision,
                                          l_user_id);

   ELSIF l_document_type = 'RELEASE' THEN

        l_release_num := wf_engine.GetItemAttrNumber (itemtype => itemtype,
                                         itemkey  => itemkey,
                                         aname    => 'RELEASE_NUM');

        l_request_id := Print_Release(l_document_num, l_qty_precision,
                                      to_char(l_release_num), l_user_id);

   ELSE
        l_request_id := Print_PO(l_document_num, l_qty_precision,
                                          l_user_id, l_orgid );
   END IF;

   wf_engine.SetItemAttrNumber (itemtype => itemtype,
                                itemkey  => itemkey,
                                aname    => 'CONCURRENT_REQUEST_ID',
                                avalue   => l_request_id);

  x_progress := 'PO_REQAPPROVAL_INIT1.PrintDocument: 02. request_id= ' || to_char(l_request_id);
  /* DEBUG */  PO_WF_DEBUG_PKG.insert_debug(itemtype,itemkey,x_progress);

EXCEPTION

   WHEN OTHERS THEN
        wf_core.context('PO_REQAPPROVAL_INIT1','PrintDocument',x_progress);
        raise;

END PrintDocument;

FUNCTION Print_PO(p_doc_num varchar2, p_qty_precision varchar,
                  p_user_id varchar2, l_orgid number) RETURN number is

 /* TTEC custom report name
 cust.ttec_po_printprogram is a table that has the list of org_id and the
 corresponding graphic PO printing program.
 Since the PO print programs have different parameters calls we added a record_type
 1 for the one group that requires two additional parameter, company and
 country and 2 for those that do not
 */

 cursor get_printprogram is
 select REPORT_NAME, REPORT_TYPE
---from cust.ttec_po_printprogram			-- Commented code by IXPRAVEEN-ARGANO,18-july-2023
from apps.ttec_po_printprogram              --  code Added by IXPRAVEEN-ARGANO,   18-july-2023
	where P_ORGID = l_orgid;

l_request_id number;
x_progress varchar2(200);
x_short_name  varchar2(200);
x_report_type number;
x_report_name varchar2(200);
BEGIN

BEGIN
     OPEN get_printprogram;
     FETCH get_printprogram into x_report_name,x_report_type;
     x_short_name := x_report_name;
	 CLOSE get_printprogram;

EXCEPTION
   when no_data_found then
   		x_short_name := 'TTEC_TTEC_US_PDF_PO';
	    x_report_type := 1;
   WHEN OTHERS THEN
        	x_short_name := 'TTEC_TTEC_US_PDF_PO';
	        x_report_type := 1;

END;

--l_request_id := fnd_request.submit_request('CUST',
  --              x_short_name,
    --            null,
      --          null,
        --        false,
          --      'P_REPORT_TYPE=R',
          --      'P_TEST_FLAG=N',
           --     'P_PO_NUM_FROM=' || p_doc_num,
           --     'P_PO_NUM_TO='   || p_doc_num,
            --    'P_USER_ID=' || p_user_id,
             --   'P_QTY_PRECISION=' || p_qty_precision,
		--		fnd_global.local_chr(0), NULL,NULL,
         --       NULL, NULL, NULL, NULL, NULL, NULL, NULL,
		--		NULL, NULL, 'P_TTEC_ORG=NGN',
	--			'P_TTEC_COUNTRY=US', NULL, NULL, NULL,
     --           NULL, NULL, NULL, NULL, NULL, NULL, NULL,

--x_short_name := 'POXPPO';

-- x_short_name := 'TTEC_US_CA_PDF_PO';

-- x_short_name := 'TTEC_TTEC_US_PDF_PO';
-- x_short_name :=  'TTEC_NEWGEN_PDF_PO';
/* if l_orgid = 101 then                -- TTEC US
x_short_name := 'TTEC_TTEC_US_PDF_PO';
ELSIF l_orgid = 141 then           -- TTEC canada
x_short_name := 'TTEC_TTEC_US_PDF_PO';
ELSIF l_orgid = 142 then           -- TTEC canada
x_short_name := 'TTEC_TTEC_US_PDF_PO';
ELSIF l_orgid = 121 then       -- US Percepta
x_short_name := 'TTEC_PERCEPTA_US_PDF_PO';
ELSIF l_orgid = 221 then  -- Newgen US
x_short_name := 'TTEC_NEWGEN_PDF_PO';
ELSIF l_orgid = 241 then   -- Newgen Canada
x_short_name := 'TTEC_NEWGEN_PDF_PO';
ELSIF l_orgid = 161 then  -- TTEC UK
x_short_name := 'TTEC_TTEC_UK_PDF_PO';
ELSIF l_orgid = 181 then  -- TTEC UK
x_short_name := 'TTEC_PERCEPTA_UK_PDF_PO';
-- ELSIF l_orgid = 261 then  -- TTEC UK
-- x_short_name := 'TTEC_PERCEPTA_UK_PDF_PO';

end if;
*/
-- x_short_name :=  'TTEC_SPAIN_PDF_PO';


    if x_report_type = 1 then
    l_request_id := fnd_request.submit_request('CUST',
                x_short_name,
                null,
                null,
                false,
                'R',
				 NULL,
                 p_doc_num,
                 p_doc_num,
                 NULL,
				 NULL,
				 NULL,
				 NULL,
				 NULL,
				 NULL,
				 'Y',
				 NULL,
				 p_user_id,
                 p_qty_precision,
				 'N',NULL,'Y',
                 'N',
				 'NGN',
				 'US', fnd_global.local_chr(0), NULL, NULL,
                NULL, NULL, NULL, NULL, NULL, NULL, NULL,
                NULL, NULL, NULL, NULL, NULL, NULL, NULL,
                NULL, NULL, NULL, NULL, NULL, NULL, NULL,
                NULL, NULL, NULL, NULL, NULL, NULL, NULL,
                NULL, NULL, NULL, NULL, NULL, NULL, NULL,
                NULL, NULL, NULL, NULL, NULL, NULL, NULL,
                NULL, NULL, NULL, NULL, NULL, NULL, NULL,
                NULL, NULL, NULL, NULL, NULL, NULL, NULL,
                NULL, NULL, NULL, NULL, NULL, NULL, NULL,
                NULL, NULL, NULL, NULL, NULL, NULL, NULL,
                NULL, NULL, NULL, NULL, NULL, NULL, NULL);
            else
				 l_request_id := fnd_request.submit_request('CUST',
                x_short_name,
                null,
                null,
                false,
                'R',
				 NULL,
                 p_doc_num,
                 p_doc_num,
                 NULL,
				 NULL,
				 NULL,
				 NULL,
				 NULL,
				 NULL,
				 'Y',
				 NULL,
				 p_user_id,
                 p_qty_precision,
				 'N',NULL,'Y',
                 'N',
				fnd_global.local_chr(0), NULL, NULL,
                NULL, NULL, NULL, NULL, NULL, NULL, NULL,
                NULL, NULL, NULL, NULL, NULL, NULL, NULL,
                NULL, NULL, NULL, NULL, NULL, NULL, NULL,
                NULL, NULL, NULL, NULL, NULL, NULL, NULL,
                NULL, NULL, NULL, NULL, NULL, NULL, NULL,
                NULL, NULL, NULL, NULL, NULL, NULL, NULL,
                NULL, NULL, NULL, NULL, NULL, NULL, NULL,
                NULL, NULL, NULL, NULL, NULL, NULL, NULL,
                NULL, NULL, NULL, NULL, NULL, NULL, NULL,
                NULL, NULL, NULL, NULL, NULL, NULL, NULL,
                NULL, NULL, NULL, NULL, NULL, NULL, NULL);

	end if;



    return(l_request_id);

EXCEPTION

   WHEN OTHERS THEN
        wf_core.context('PO_REQAPPROVAL_INIT1','Print_PO',x_progress);
        raise;

END Print_PO;






FUNCTION Print_Requisition(p_doc_num varchar2, p_qty_precision varchar,
                           p_user_id varchar2) RETURN number is

l_request_id NUMBER;
x_progress varchar2(200);

BEGIN

     l_request_id := fnd_request.submit_request('PO',
                'PRINTREQ',
                null,
                null,
                false,
                'P_REQ_NUM_FROM=' || p_doc_num,
                'P_REQ_NUM_TO=' || p_doc_num,
                'P_QTY_PRECISION=' || p_qty_precision,
                fnd_global.local_chr(0),
                NULL,
                NULL,
                NULL,
                NULL, NULL,
                NULL, NULL, NULL, NULL, NULL, NULL, NULL,
                NULL, NULL, NULL, NULL, NULL, NULL, NULL,
                NULL, NULL, NULL, NULL, NULL, NULL, NULL,
                NULL, NULL, NULL, NULL, NULL, NULL, NULL,
                NULL, NULL, NULL, NULL, NULL, NULL, NULL,
                NULL, NULL, NULL, NULL, NULL, NULL, NULL,
                NULL, NULL, NULL, NULL, NULL, NULL, NULL,
                NULL, NULL, NULL, NULL, NULL, NULL, NULL,
                NULL, NULL, NULL, NULL, NULL, NULL, NULL,
                NULL, NULL, NULL, NULL, NULL, NULL, NULL,
                NULL, NULL, NULL, NULL, NULL, NULL, NULL,
                NULL, NULL, NULL, NULL, NULL, NULL, NULL,
                NULL, NULL, NULL, NULL, NULL, NULL, NULL);

    return(l_request_id);

EXCEPTION

   WHEN OTHERS THEN
        wf_core.context('PO_REQAPPROVAL_INIT1','Print_Requisition',x_progress);
        raise;
END;









FUNCTION Print_Release(p_doc_num varchar2, p_qty_precision varchar,
             p_release_num varchar2, p_user_id varchar2) RETURN number is

l_request_id number;
x_progress varchar2(200);

BEGIN
     -- FRKHAN 09/17/98. Change 'p_doc_num || p_release_num' from P_RELEASE_NUM_FROM and TO to just p_release_num
     l_request_id := fnd_request.submit_request('PO',
                'POXPPO',
                null,
                null,
                false,
                'P_REPORT_TYPE=R',
                'P_TEST_FLAG=N',
                'P_USER_ID=' || p_user_id,
                'P_PO_NUM_FROM=' || p_doc_num,
                'P_PO_NUM_TO=' || p_doc_num,
                'P_RELEASE_NUM_FROM=' || p_release_num,
                'P_RELEASE_NUM_TO='   || p_release_num,
                'P_QTY_PRECISION=' || p_qty_precision,
                fnd_global.local_chr(0),
                NULL, NULL, NULL, NULL, NULL, NULL, NULL,
                NULL, NULL, NULL, NULL, NULL, NULL, NULL,
                NULL, NULL, NULL, NULL, NULL, NULL, NULL,
                NULL, NULL, NULL, NULL, NULL, NULL, NULL,
                NULL, NULL, NULL, NULL, NULL, NULL, NULL,
                NULL, NULL, NULL, NULL, NULL, NULL, NULL,
                NULL, NULL, NULL, NULL, NULL, NULL, NULL,
                NULL, NULL, NULL, NULL, NULL, NULL, NULL,
                NULL, NULL, NULL, NULL, NULL, NULL, NULL,
                NULL, NULL, NULL, NULL, NULL, NULL, NULL,
                NULL, NULL, NULL, NULL, NULL, NULL, NULL,
                NULL, NULL, NULL, NULL, NULL, NULL, NULL,
                NULL, NULL, NULL, NULL, NULL, NULL, NULL);


    return(l_request_id);

EXCEPTION

   WHEN OTHERS THEN
        wf_core.context('PO_REQAPPROVAL_INIT1','Print_Release',x_progress);
        raise;

END Print_Release;









end PO_REQAPPROVAL_TTEC1;
/
show errors;
/