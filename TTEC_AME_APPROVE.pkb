create or replace PACKAGE BODY TTEC_AME_APPROVE AS

  /*
  -------------------------------------------------------------

  Program Name    :  ttec_ame_approve

  Desciption      : To get approver from AME


  Input/Output Parameters

  Input :  transaction id
  output : person id


  Created By      :  Elango Pandu
  Date               : 24-June-2013

  Modification Log:
  -----------------
  Ver        Developer             Date                    Description
1.0	IXPRAVEEN(ARGANO)  17-May-2023		R12.2 Upgrade Remediation

  */

  FUNCTION TTEC_SOURCE_APPROVER(P_TRANSACTION_ID NUMBER) RETURN VARCHAR2 IS

    L_RESULT VARCHAR2(25);

    /*
    CURSOR c1 IS
         SELECT 'person_id:'|| 1108180
         FROM mtl_categories_b_kfv mck, po_requisition_lines_all prl, po_req_distributions_all prd
         WHERE mck.category_id = prl.category_id
         AND prl.requisition_line_id = prd.requisition_line_id
         AND prl.requisition_header_id = p_transaction_id --po_ame_setup_pvt.get_new_req_header_id(:transactionId)
         AND mck.category_id = 4017;
         --AND mck.category_id = :item_category
    */
    CURSOR C1 IS
      SELECT 'person_id:' || PAPF.PERSON_ID -- 108180 -- 994993 -- 996861
        --FROM APPLSYS.FND_LOOKUP_TYPES_TL A,				-- Commented code by IXPRAVEEN-ARGANO,17-May-2023
        FROM APPS.FND_LOOKUP_TYPES_TL A,                    --  code Added by IXPRAVEEN-ARGANO,   17-May-2023
             APPS.FND_LOOKUP_VALUES      B,
             APPS.MTL_CATEGORIES_B_KFV   C,
             APPS.PER_ALL_PEOPLE_F       PAPF,
             PO_REQUISITION_LINES_ALL    PRL,
             PO_REQ_DISTRIBUTIONS_ALL    PRD
       WHERE A.LOOKUP_TYPE = B.LOOKUP_TYPE
            --AND a.LOOKUP_TYPE =  'TTEC_SOURCE_APPROVER'
         AND A.LANGUAGE = 'US'
         AND B.LANGUAGE = 'US'
         AND A.DESCRIPTION = 'TTEC_AME_SOURCE_APPROVER'
         AND C.ENABLED_FLAG = 'Y'
         AND LTRIM(RTRIM(UPPER(C.CONCATENATED_SEGMENTS))) =
             LTRIM(RTRIM(UPPER(B.MEANING)))
         AND PAPF.EMPLOYEE_NUMBER = A.MEANING
         AND SYSDATE BETWEEN PAPF.EFFECTIVE_START_DATE AND
             PAPF.EFFECTIVE_END_DATE
         AND C.CATEGORY_ID = PRL.CATEGORY_ID
         AND PRL.REQUISITION_LINE_ID = PRD.REQUISITION_LINE_ID
         AND PRL.REQUISITION_HEADER_ID = P_TRANSACTION_ID; --987665; --po_ame_setup_pvt.get_new_req_header_id(:transactionId)

  BEGIN

    OPEN C1;
    FETCH C1
      INTO L_RESULT;
    CLOSE C1;

    RETURN L_RESULT;

  EXCEPTION
    WHEN OTHERS THEN
      L_RESULT := NULL;
      RETURN L_RESULT;

  END TTEC_SOURCE_APPROVER;


FUNCTION TTEC_FINANCE_APPROVER(P_TRANSACTION_ID NUMBER) RETURN VARCHAR2

  /*
  -------------------------------------------------------------

  Program Name    :  ttec_ame_approve

  Desciption      : To get approver from AME


  Input/Output Parameters

  Input :  transaction id
  output : person id


  Created By      :  Elango Pandu
  Date               : 24-June-2013

  Modification Log:
  -----------------
  Ver        Developer             Date                    Description
  1.1        Arun Kumar            08/05/2015              Code change to fetch finance approver based
                                                           on department code of requestor.

  */

 IS

  L_RESULT VARCHAR2(25);
  l_seg3   VARCHAR2(100);

  /*
     CURSOR c1 IS
          SELECT 'person_id:'|| 996861
          --SELECT 1108180
          from mtl_categories_b_kfv mck, po_requisition_lines_all prl, po_req_distributions_all prd
          where mck.category_id = prl.category_id
          and prl.requisition_line_id = prd.requisition_line_id
          and prl.requisition_header_id = p_transaction_id --po_ame_setup_pvt.get_new_req_header_id(:transactionId)
          AND mck.category_id = 4017;
          --AND mck.category_id = :item_category
  */

  /*
  SELECT c.category_id,papf.person_id,a.meaning approver,b.meaning cat
  FROM applsys.fnd_lookup_types_tl  a
  ,apps.fnd_lookup_values b
  ,apps.mtl_categories_b_kfv c
  ,apps.per_all_people_f papf
  , po_requisition_lines_all prl, po_req_distributions_all prd
  WHERE a.lookup_type = b.lookup_type
  AND a.LOOKUP_TYPE =  'TTEC_FIN_APPROVER1'
  AND a.language = 'US'
  AND b.language = 'US'
  AND a.description = 'TTEC_AME_FIN_APPROVER'
  AND c.enabled_flag = 'Y'
  AND LTRIM(RTRIM(UPPER(c.concatenated_segments))) = LTRIM(RTRIM(UPPER(b.meaning)))
  AND papf.employee_number = a.meaning
  AND SYSDATE BETWEEN papf.effective_start_date AND papf.effective_end_date
  AND c.category_id = prl.category_id
  AND prl.requisition_line_id = prd.requisition_line_id
  AND prl.requisition_header_id = 1  p_transaction_id --po_ame_setup_pvt.get_new_req_header_id(:transactionId)

  */

  /* CURSOR C1 IS
      --SELECT 'person_id:'||to_number(papf.person_id)
        SELECT 'person_id:' || PAPF.PERSON_ID -- 108180 -- 994993 -- 996861
          FROM APPLSYS.FND_LOOKUP_TYPES_TL A,
               APPS.FND_LOOKUP_VALUES      B,
               APPS.MTL_CATEGORIES_B_KFV   C,
               APPS.PER_ALL_PEOPLE_F       PAPF,
               PO_REQUISITION_LINES_ALL    PRL,
               PO_REQ_DISTRIBUTIONS_ALL    PRD
         WHERE A.LOOKUP_TYPE = B.LOOKUP_TYPE
              --AND a.LOOKUP_TYPE =  'TTEC_FIN_APPROVER1'
           AND A.LANGUAGE = 'US'
           AND B.LANGUAGE = 'US'
           AND A.DESCRIPTION = 'TTEC_AME_FIN_APPROVER'
           AND C.ENABLED_FLAG = 'Y'
           AND LTRIM(RTRIM(UPPER(c.concatenated_segments))) = LTRIM(RTRIM(UPPER( b.meaning )))
           AND PAPF.EMPLOYEE_NUMBER = A.MEANING
           AND SYSDATE BETWEEN PAPF.EFFECTIVE_START_DATE AND
               PAPF.EFFECTIVE_END_DATE
           AND C.CATEGORY_ID = PRL.CATEGORY_ID
           AND PRL.REQUISITION_LINE_ID = PRD.REQUISITION_LINE_ID
           AND PRL.REQUISITION_HEADER_ID = P_TRANSACTION_ID; --987665; --po_ame_setup_pvt.get_new_req_header_id(:transactionId)
  */

/* Ver 1.1 - Start */

  CURSOR c_dept_code IS
    SELECT gcc.segment3
      FROM apps.po_requisition_headers_all prha,
           apps.po_requisition_lines_all   prla,
           apps.per_all_people_f           papf,
           apps.per_all_assignments_f      pasf,
           apps.gl_code_combinations       gcc
     WHERE prha.requisition_header_id = prla.requisition_header_id
       AND prla.to_person_id = papf.person_id
       AND papf.person_id = pasf.person_id
       AND pasf.default_code_comb_id = gcc.code_combination_id
       AND TRUNC(SYSDATE) BETWEEN papf.effective_start_date AND
           papf.effective_end_date
       AND TRUNC(SYSDATE) BETWEEN pasf.effective_start_date AND
           pasf.effective_end_date
       AND prha.requisition_header_id = P_TRANSACTION_ID;


  CURSOR C1 IS
  --SELECT 'person_id:'||to_number(papf.person_id)
    SELECT 'person_id:' || PAPF.PERSON_ID -- 108180 -- 994993 -- 996861
      --FROM APPLSYS.FND_LOOKUP_TYPES_TL A,					-- Commented code by IXPRAVEEN-ARGANO,17-May-2023
      FROM APPS.FND_LOOKUP_TYPES_TL A,                      --  code Added by IXPRAVEEN-ARGANO,   17-May-2023
           APPS.FND_LOOKUP_VALUES      B,
           APPS.PER_ALL_PEOPLE_F       PAPF
     WHERE A.LOOKUP_TYPE = B.LOOKUP_TYPE
       AND LTRIM(RTRIM(UPPER(l_seg3))) = LTRIM(RTRIM(UPPER(B.MEANING)))
       AND NVL(PAPF.EMPLOYEE_NUMBER, PAPF.NPW_NUMBER) = B.DESCRIPTION
       AND A.LANGUAGE = 'US'
       AND B.LANGUAGE = 'US'
       AND A.LOOKUP_TYPE = 'TTEC_AME_DEPT_FIN_APPROVER'
       AND TRUNC(SYSDATE) BETWEEN NVL(B.START_DATE_ACTIVE, TRUNC(SYSDATE)) AND
           NVL(B.END_DATE_ACTIVE, TRUNC(SYSDATE) + 1)
       AND TRUNC(SYSDATE) BETWEEN PAPF.EFFECTIVE_START_DATE AND
           PAPF.EFFECTIVE_END_DATE
       AND B.ENABLED_FLAG = 'Y';

/* Ver 1.1 - End */

BEGIN

/* Ver 1.1 - Start */

    OPEN c_dept_code;
    FETCH c_dept_code
      INTO l_seg3;
    CLOSE c_dept_code;

/* Ver 1.1 - End */

    OPEN C1;
    FETCH C1
      INTO L_RESULT;
    CLOSE C1;

    RETURN L_RESULT;

  EXCEPTION
    WHEN OTHERS THEN
      L_RESULT := NULL;
      RETURN L_RESULT;

  END TTEC_FINANCE_APPROVER;

  FUNCTION TTEC_BILLABLE_APPROVER(P_TRANSACTION_ID NUMBER) RETURN VARCHAR2

    /*
    -------------------------------------------------------------

    Program Name    :  ttec_ame_approve

    Desciption      : To get approver from AME


    Input/Output Parameters

    Input :  transaction id
    output : person id


    Created By      :  Srinivas Ravada
    Date               : 03-Apr-2013

    Modification Log:
    -----------------
    Ver        Developer             Date                    Description


    */

   IS

    L_RESULT VARCHAR2(25);

    CURSOR C1 IS
      SELECT 'person_id:' || PAPF.PERSON_ID
        --FROM APPLSYS.FND_LOOKUP_TYPES_TL A,			-- Commented code by IXPRAVEEN-ARGANO,17-May-2023
        FROM APPS.FND_LOOKUP_TYPES_TL A,             --  code Added by IXPRAVEEN-ARGANO,   17-May-2023
             APPS.FND_LOOKUP_VALUES      B,
             APPS.MTL_CATEGORIES_B_KFV   C,
             APPS.PER_ALL_PEOPLE_F       PAPF,
             PO_REQUISITION_LINES_ALL    PRL,
             PO_REQ_DISTRIBUTIONS_ALL    PRD,
             PO_REQUISITION_HEADERS_ALL  PRH
       WHERE A.LOOKUP_TYPE = B.LOOKUP_TYPE
         AND A.LANGUAGE = 'US'
         AND B.LANGUAGE = 'US'
         AND A.DESCRIPTION = 'TTECH_BILLABLE_APPROVER'
         AND C.ENABLED_FLAG = 'Y'
         AND LTRIM(RTRIM(UPPER(C.CONCATENATED_SEGMENTS))) =
             LTRIM(RTRIM(UPPER(SUBSTR(B.MEANING,
                                      1,
                                      DECODE(INSTR(B.MEANING, '-'),
                                             0,
                                             LENGTH(B.MEANING || '-'),
                                             INSTR(B.MEANING, '-')) - 1))))
         --AND LTRIM(RTRIM(UPPER(C.CONCATENATED_SEGMENTS))) = LTRIM(RTRIM(UPPER(B.MEANING)))
         AND PAPF.EMPLOYEE_NUMBER = B.DESCRIPTION
         AND SYSDATE BETWEEN PAPF.EFFECTIVE_START_DATE AND
             PAPF.EFFECTIVE_END_DATE
         AND C.CATEGORY_ID = PRL.CATEGORY_ID
         AND PRH.ORG_ID = TO_NUMBER(B.TAG)
         AND PRL.REQUISITION_LINE_ID = PRD.REQUISITION_LINE_ID
         AND PRH.REQUISITION_HEADER_ID  = PRL.REQUISITION_HEADER_ID
         AND PRL.REQUISITION_HEADER_ID = P_TRANSACTION_ID;

  BEGIN

    OPEN C1;
    FETCH C1
      INTO L_RESULT;
    CLOSE C1;

    RETURN L_RESULT;

  EXCEPTION
    WHEN OTHERS THEN
      L_RESULT := NULL;
      RETURN L_RESULT;

  END TTEC_BILLABLE_APPROVER;

  FUNCTION TTEC_BILLABLE_CATEGORY(P_TRANSACTION_ID NUMBER) RETURN VARCHAR2

    /*
    -------------------------------------------------------------

    Program Name    :  ttec_ame_approve

    Desciption      : To get approver from AME


    Input/Output Parameters

    Input :  transaction id
    output : person id


    Created By      :  Srinivas Ravada
    Date               : 03-Apr-2013

    Modification Log:
    -----------------
    Ver        Developer             Date                    Description


    */

   IS

    L_RESULT VARCHAR2(25) := 'false';

    CURSOR C1 IS
      SELECT 'true'
        FROM DUAL
       WHERE EXISTS
       (SELECT *
                --FROM APPLSYS.FND_LOOKUP_TYPES_TL A,			-- Commented code by IXPRAVEEN-ARGANO,17-May-2023
                FROM APPS.FND_LOOKUP_TYPES_TL A,                --  code Added by IXPRAVEEN-ARGANO,   17-May-2023
                     APPS.FND_LOOKUP_VALUES      B,
                     APPS.MTL_CATEGORIES_B_KFV   C,
                     PO_REQUISITION_LINES_ALL    PRL,
                     PO_REQUISITION_HEADERS_ALL  PRH
               WHERE A.LOOKUP_TYPE = B.LOOKUP_TYPE
                 AND A.LANGUAGE = 'US'
                 AND B.LANGUAGE = 'US'
                 AND A.DESCRIPTION = 'TTECH_BILLABLE_ITEM_CATEGORY'
                 AND C.ENABLED_FLAG = 'Y'
                 AND LTRIM(RTRIM(UPPER(C.CONCATENATED_SEGMENTS))) = LTRIM(RTRIM(UPPER(B.MEANING)))
                 AND C.CATEGORY_ID = PRL.CATEGORY_ID
                 AND PRL.REQUISITION_HEADER_ID = PRH.REQUISITION_HEADER_ID
                 AND PRH.REQUISITION_HEADER_ID =
                     PO_AME_SETUP_PVT.GET_NEW_REQ_HEADER_ID(P_TRANSACTION_ID));

  BEGIN

    OPEN C1;
    FETCH C1
      INTO L_RESULT;
    CLOSE C1;

    RETURN L_RESULT;

  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      L_RESULT := 'false';
      RETURN L_RESULT;
    WHEN OTHERS THEN
      L_RESULT := 'false';
      RETURN L_RESULT;

  END TTEC_BILLABLE_CATEGORY;

END TTEC_AME_APPROVE;
/
show errors;
/