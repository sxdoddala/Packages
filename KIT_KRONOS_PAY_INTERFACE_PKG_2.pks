create or replace PACKAGE      KIT_KRONOS_PAY_INTERFACE_PKG_2 IS

/*-----------------------------------------------------------------------
Program Name    : KIT_KRONOS_PAY_INTERFACE_PKG_2
Desciption      : This is a copy of the pre-existing custom
   KIT_KRONOS_PAY_INTERFACE_PKG.  The original package is called by the
   Kronos Connect process for all non-GBP2 countries and creates a BEE
   Batch with all assignment and element updates.

   It has been modified to take Country Code instead of Business Group ID
   as input as Kronos will no longer maintain the BG ID.  The original
   version will remain in place so that KRONOS can cleanly transition from
   the prior version to the new when ready.

   Modification Log:
   Version       Developer  Date        Description
   -------       ---------  ---------   ----------------------------------------------------
    1.0          M Dodge    12/20/2007  Replace Business Group ID with Country Code param.
    1.1          M Dodge    12/27/2007  Added Date_Earned to the BEE Batch Lines.
    1.2          C.Chan     06/23/2015  Fix for FMLA Leave PTO - unlike other elements.
                                        the elements "FMLA Leave PTO" and "FMLA Leave Paid Sick"
                                        are using VALUE_2 instead of VALUE_1.
   1.3          Elango Pandu  8/23/2018 Added date format change as encounter the error Alan's data
                                       Added mulitiple Atelka elements are using for value 2 instead of value 1
--------------------------------------------------------------------------------------------*/

---------------------------------
--  General Use Variables
---------------------------------
l_rows_processed number := 0;
l_rows_lines_processed number := 0;
l_dummy_line_id number;
l_bus_group_id number;
l_batch_id number;
l_batch_name varchar(60);
l_batch_line_id number;
l_object_version_number number;
l_batch_run_number number := 1;
l_effective_end_date date;
l_effective_start_date date;
l_batch_control_id number;
l_sequence_no number;
l_total_hours varchar(60);
l_last_element_name varchar(60);
L_ERROR_RECORD varchar(2000);
L_ERROR_MESSAGE varchar(2000);
l_element_type_id varchar(60);
l_assignment_id varchar(60);


--
--------------------------------------------------------------------
--        CURSOR DECLARATIONS
--------------------------------------------------------------------
--
--Element cursor for validating the element names exist in the oracle system.

/*
cursor csr_element(element_name_val varchar2,payroll_end_date varchar2, vBusGroup number) is
--
	select element_type_id
	from pay_element_types_f
	where element_name = element_name_val
	and TO_DATE(payroll_end_date,'DD-MON-YY')
	BETWEEN EFFECTIVE_START_DATE AND EFFECTIVE_END_DATE AND
      Business_group_id = vBusGroup;
*/
-- elango modified date format
cursor csr_element(element_name_val varchar2,payroll_end_date date, vBusGroup number) is
--
    select element_type_id
    from pay_element_types_f
    where element_name = element_name_val
    --and TO_DATE(payroll_end_date,'DD-MON-YY')
    and payroll_end_date
    BETWEEN EFFECTIVE_START_DATE AND EFFECTIVE_END_DATE AND
      Business_group_id = vBusGroup;



--
--Assignment cursor to verify that the assignment alreay exists
/*
cursor csr_assignment(assignment_number_val varchar2,payroll_end_date varchar2, vBusGroup number) is
--
	select A.assignment_id
	from per_assignments_f A,PER_ALL_PEOPLE_F B
	where A.PERSON_ID=B.PERSON_ID AND
	assignment_number = assignment_number_val
	AND TO_DATE(payroll_end_date,'DD-MON-YY')
	BETWEEN B.EFFECTIVE_START_DATE
	AND B.EFFECTIVE_END_DATE
	AND TO_DATE(payroll_end_date,'DD-MON-YY')
	BETWEEN A.EFFECTIVE_START_DATE
	AND A.EFFECTIVE_END_DATE AND
      A.Business_group_id = vBusGroup;
*/
-- elango modified this cursor date format issue

cursor csr_assignment(assignment_number_val varchar2,payroll_end_date date, vBusGroup number) is
--
    select A.assignment_id
    from per_assignments_f A,PER_ALL_PEOPLE_F B
    where A.PERSON_ID=B.PERSON_ID AND
    assignment_number = assignment_number_val
    AND payroll_end_date
    BETWEEN B.EFFECTIVE_START_DATE
    AND B.EFFECTIVE_END_DATE
    AND payroll_end_date
    BETWEEN A.EFFECTIVE_START_DATE
    AND A.EFFECTIVE_END_DATE AND
      A.Business_group_id = vBusGroup;

--Cursor for Getting the header records from the staging records.
cursor Kronos_Header_Csr(vBatchName varchar2) is
--
	Select Distinct *
	from KSS_PAYROLL_ORACLE
	where upper(BATCH_NAME) = upper(vBatchName)
	and record_Track = 'H'
	and DeletionIndicator=0 ;
	Kronos_Header_Rec Kronos_Header_Csr%ROWTYPE;

-- Elango modified followign query to add element name condition and adding new elements
-- look for value 2

--Cursor for Getting the Line Records from the Staging Records
cursor Kronos_Line_Csr(vBusGroup number, vBatchName varchar2) is
--
SELECT
  KPO.BATCH_NAME,
  KPO.BATCH_DATE,
  KPO.RECORD_TRACK,
  KPO.ELEMENT_TYPE_ID,
  KPO.ASSIGNMENT_NUMBER,
  KPO.ASSIGNMENT_ID,
  KPO.ELEMENT_NAME,
  KPO.ENTRY_TYPE,
  KPO.REASON,
  KPO.VALUE_1,
  KPO.VALUE_2,
  KPO.VALUE_3,
  KPO.EFFECTIVE_DATE,
  KPO.DELETIONINDICATOR,
  KPO.EFFECTIVE_START_DATE,
  KPO.EFFECTIVE_END_DATE,
  KPO.DATE_EARNED
FROM
  KRONOS.KSS_PAYROLL_ORACLE KPO,
  (SELECT
    BATCH_NAME,
    ASSIGNMENT_NUMBER,
    element_name,
--  SUM(VALUE_1) /* 1.2 */
    SUM(decode(element_name, 'FMLA Leave PTO', VALUE_2,
                             'FMLA Leave Paid Sick', VALUE_2,
                             'Admin Hours_Atelka', VALUE_2,
                             'Emergency Leave', VALUE_2,
                             'Nesting_Atelka', VALUE_2,
                             'NightPremium_Atelka', VALUE_2,
                             'Overtime 1_5 Adjustment', VALUE_2,
                             'Parental Leave', VALUE_2,
                             'Prime OVT', VALUE_2,
                             'Public Hol Straight Time', VALUE_2,
                             'Training_NB', VALUE_2,
                             'Training_ON', VALUE_2,
                             'Training_PE', VALUE_2,
                             'Training_QC', VALUE_2,
                             'ADM 0_5', VALUE_2,
                             'ADM 1', VALUE_2,
                             'ADM 2', VALUE_2,
                             'ADM 3', VALUE_2,
                             'ADM 4', VALUE_2,
                              VALUE_1))  /* 1.2 */
  FROM
  -- KRONOS.KSS_PAYROLL_ORACLE  --Commented code by MXKEERTHI-ARGANO, 05/05/2023
 apps.KSS_PAYROLL_ORACLE   --code added by MXKEERTHI-ARGANO, 05/05/2023
  WHERE ELEMENT_NAME IN (SELECT ELEMENT_NAME FROM PAY_ELEMENT_TYPES_F
                        where business_group_id = vBusGroup) AND
	BATCH_NAME = vBatchName AND
    BATCH_DATE = BATCH_DATE AND
    RECORD_TRACK ='L' AND
    DELETIONINDICATOR=0
  GROUP BY
    BATCH_NAME,
    ASSIGNMENT_NUMBER,
    element_name
--  HAVING SUM(VALUE_1) >= 0) MG /* 1.2 */
--HAVING SUM(decode(element_name, 'FMLA Leave PTO', VALUE_2, 'FMLA Leave Paid Sick', VALUE_2, VALUE_1)) >= 0) MG  /* 1.2 */
HAVING
    (SUM(decode(element_name, 'FMLA Leave PTO', VALUE_2,
                             'FMLA Leave Paid Sick', VALUE_2,
                             'Admin Hours_Atelka', VALUE_2,
                             'Emergency Leave', VALUE_2,
                             'Nesting_Atelka', VALUE_2,
                             'NightPremium_Atelka', VALUE_2,
                             'Overtime 1_5 Adjustment', VALUE_2,
                             'Parental Leave', VALUE_2,
                             'Prime OVT', VALUE_2,
                             'Public Hol Straight Time', VALUE_2,
                             'Training_NB', VALUE_2,
                             'Training_ON', VALUE_2,
                             'Training_PE', VALUE_2,
                             'Training_QC', VALUE_2,
                             'ADM 0_5', VALUE_2,
                             'ADM 1', VALUE_2,
                             'ADM 2', VALUE_2,
                             'ADM 3', VALUE_2,
                             'ADM 4', VALUE_2,
                              VALUE_1))) >= 0) MG  /* 1.2 */
WHERE KPO.ELEMENT_NAME IN (SELECT ELEMENT_NAME FROM PAY_ELEMENT_TYPES_F where business_group_id = vBusGroup) AND
  MG.BATCH_NAME = KPO.BATCH_NAME AND
  MG.ASSIGNMENT_NUMBER = KPO.ASSIGNMENT_NUMBER AND
  MG.element_name = kpo.element_name AND
  KPO.BATCH_NAME = vBatchName AND
  RECORD_TRACK ='L' AND
  DELETIONINDICATOR=0
order by KPO.ELEMENT_NAME;

  Kronos_Line_Rec  Kronos_Line_Csr%ROWTYPE;

--
-------------------------------------------------------------------
--        PROCEDURE AND FUNCTION DECLARATIONS
-------------------------------------------------------------------
--
--Main Procedure for the Payroll Interface.
PROCEDURE KIT_KRONOS_PAYROLL_INTERFACE  (vCountryCode varchar2, vBatchName varchar2)  ;

END KIT_KRONOS_PAY_INTERFACE_PKG_2;
/
show errors;
/