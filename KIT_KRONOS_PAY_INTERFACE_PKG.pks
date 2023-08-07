create or replace PACKAGE KIT_KRONOS_PAY_INTERFACE_PKG IS
/************************************************************************************
        Program Name: TTEC_PO_TSG_INTERFACE 

        Description:   

        Developed by : 
        Date         :  

       Modification Log
       Name                  Version #    Date            Description
       -----                 --------     -----           -------------
   MXKEERTHI(ARGANO)  17-JUL-2023           1.0          R12.2 Upgrade Remediation
    ****************************************************************************************/
               

---------------------------------
--  General Use Variables
---------------------------------
l_rows_processed number := 0;
l_rows_lines_processed number := 0;
l_dummy_line_id number;
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
cursor csr_element(element_name_val varchar2,payroll_end_date varchar2, vBusGroup number) is
--
	select element_type_id
	from pay_element_types_f
	where element_name = element_name_val
	and TO_DATE(payroll_end_date,'DD-MON-YY')
	BETWEEN EFFECTIVE_START_DATE AND EFFECTIVE_END_DATE AND
      Business_group_id = vBusGroup;
--
--Assignment cursor to verify that the assignment alreay exists
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

--Cursor for Getting the header records from the staging records.
cursor Kronos_Header_Csr(vBatchName varchar2) is
--
	Select Distinct *
	from KSS_PAYROLL_ORACLE
	where upper(BATCH_NAME) = upper(vBatchName)
	and record_Track = 'H'
	and DeletionIndicator=0 ;
	Kronos_Header_Rec Kronos_Header_Csr%ROWTYPE;
----EXIT WHEN csr_name%NOTFOUND;

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
  KPO.EFFECTIVE_END_DATE
  
FROM
 --  KRONOS.KSS_PAYROLL_ORACLE KPO,  --Commented code by MXKEERTHI-ARGANO,07/17/2023
  apps.KSS_PAYROLL_ORACLE KPO, --code added by MXKEERTHI-ARGANO, 07/17/2023

  (SELECT
    BATCH_NAME,
    ASSIGNMENT_NUMBER,
    SUM(VALUE_1)
  FROM
   --   KRONOS.KSS_PAYROLL_ORACLE  --Commented code by MXKEERTHI-ARGANO,07/17/2023
   apps.KSS_PAYROLL_ORACLE   --code added by MXKEERTHI-ARGANO, 07/17/2023
 
  WHERE ELEMENT_NAME IN (SELECT ELEMENT_NAME FROM PAY_ELEMENT_TYPES_F
                        where business_group_id = vBusGroup) AND
	BATCH_NAME = vBatchName AND
    RECORD_TRACK ='L' AND
    DELETIONINDICATOR=0
  GROUP BY
    BATCH_NAME,
    ASSIGNMENT_NUMBER
  HAVING SUM(VALUE_1) >= 0) MG
WHERE ELEMENT_NAME IN (SELECT ELEMENT_NAME FROM PAY_ELEMENT_TYPES_F where business_group_id = vBusGroup) AND
  MG.BATCH_NAME = KPO.BATCH_NAME AND
  MG.ASSIGNMENT_NUMBER = KPO.ASSIGNMENT_NUMBER AND
  KPO.BATCH_NAME = vBatchName AND
  RECORD_TRACK ='L' AND
  DELETIONINDICATOR=0
order by KPO.ELEMENT_NAME;

  Kronos_Line_Rec  Kronos_Line_Csr%ROWTYPE;

-- OLD SCRIPT DAS
--	Select *
--	from KSS_PAYROLL_ORACLE
--	where trim(record_Track) ='L'
--	and DeletionIndicator=0 and TRIM(UPPER(element_name)) IN (select --TRIM(UPPER(element_name)) from pay_element_types_f) order by element_name;
--EXIT WHEN Kronos_Line_Rec%NOTFOUND;
--	Kronos_Line_Rec  Kronos_Line_Csr%ROWTYPE;

--Cursor for Calculating the Batch Total Hrs
--cursor Kronos_Total_Csr(batch_name_val varchar) is
--
--	select SUM(VALUE_2) as TotalHrs
--	from KSS_PAYROLL_ORACLE
--	where trim(record_Track) ='L'
--	and batch_name=batch_name_val
--	and DeletionIndicator=0;
--sel_total csr_total%ROWTYPE;

--
-------------------------------------------------------------------
--        PROCEDURE AND FUNCTION DECLARATIONS
-------------------------------------------------------------------
--
--Main Procedure for the Payroll Interface.
PROCEDURE KIT_KRONOS_PAYROLL_INTERFACE  (vBusGroup number, vBatchName varchar2)  ;

--Procedure for Logging the errors.
--PROCEDURE Log_Error;

END KIT_KRONOS_PAY_INTERFACE_PKG;
/
show errors;
/