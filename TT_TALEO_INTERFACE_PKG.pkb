create or replace PACKAGE BODY      TT_TALEO_INTERFACE_PKG

IS
    /***********************************************************************************
     Program Name: TT_TALEOINTERFACE_PKG

     Description:  This program imports new hire record from the TALEO system into
        Oracle HR.  Person, Address, Phone, Assignment, Costing AND Salary API's are used
        TO CREATE the employee RECORD.

     Created by:        Ibrahim Konak

     Date:              February 27,2007

     Modification Log

     Version    Developer              Date         Description
     ---        ----------------    -----------     --------------------------------
     1.0        Ibrahim Konak       Feb 26 2007     Created.
     1.1        Elango Pandu        Nov 19 2007     Added CWK Part
     1.2.1      MLagostena          Aug 08 2008     Added default values for PHL to update_assignment proc
     1.2.2      NMondada            Aug 08 2008     Modified proc update_address to end date Non-primary
                                                    address for employees during the rehire process
     1.3.1      NMondada            Nov 05 2008     Terminate all primary and secondary addresses without
                                                    checking for changes, and create a new primary address.
     1.3.2      MLagostena          Nov 05 2008     Modified procedure get_rehire_person to handle UK rehires
                                                    (which allow null NINS) as PHL rehires.
     1.4        MLagostena          Jan 23 2008     Added South Africa to the Integration.
     1.5        MLagostena          Jan 26 2009     Added Argentina to the Integration.
     1.6.1      MLagostena/NMondada Mar 17 2009     Added MEX to the Integration
     1.6.2      MLagostena          May 26 2009     Added Race/Ethnicity Field Validation Change (US)
     1.6.3      MLagostena          Jun 10 2009   TT#1191867  Added INITCAP to city field for all BGs except ARG and for county
     1.6.4      MLagostena          Jun 18 2009   TT#1196963  Added specific format to date field contract_start_date for MEXICO in update_assignment procedure
     1.6.5      MLagostena          Jun 18 2009   WO#584809   Added Candidate ID to procedure update_employee when the employee record is being checked for changes during re-hire.
     1.7        CChan               Jun 04 2008     Added costa Rica to the Integration.
     1.8        CChan               Jun 18 2008     Additional requirement for ZA Integration - Visa Expiration Date
     1.9        Christiane Chan     Dec 01 2009    Hirepoint Integration Enhancements - IB02
     1.10       Christiane Chan      Jan 14 2010    Hirepoint Integration Enhancements - IB07,IB08
     2.0       Christiane Chan      Jul 06 2010    Hirepoint Integration Enhancements Q2 - IB09
     2.1       Christiane Chan      Aug 09 2010    Hirepoint Integration Enhancements Q2 - Bug Fix on Mex Rehire
     2.2       Christiane Chan      Aug 10 2010    Hirepoint Integration Enhancements Q2 - Bug Fix on Mobile Phone
     2.3       Christiane Chan      Aug 17 2010    Hirepoint Integration Enhancements Q2 - Bug Fix on Arg Rehire
     2.4        WManasfi            2/21/2011      Mexico assignment category changes
     2.5        Ravi Pasula          10/29/2012     Address issue for US employees
     2.6       Ravi Pasula           02/01/2013     Taleo Brazil  Integration.
     2.7       C. Chan               04/26/13       TTSD I#2366709 - when hiring CAN @home employees getting API Error
     2.8       Christiane Chan      May 08 2013    TTSD R#2393792 - Enhancements - adding 4 new Matchpoint Field
     2.9     Kaushik                7/19/13        code changes for PRG implementation project (Hire & Rehire) for employee in countries
                                                        PRG Australia
                                                        PRG Belgium
                                                        PRG Brazil
                                                        PRG Germany
                                                        PRG Kuwait
                                                        PRG Lebanon
                                                        PRG Singapore
                                                        PRG South Africa
                                                        PRG Turkey
                                                        PRG UAE
                                                        PRG United Kingdom
     3.0       Christiane Chan      Aug 14 2013    TTSD R#2641072- Enhancements - adding 9 new Matchpoint Fields
                                                        1.	Assessment 1
                                                        2.	Assessment 2
                                                        3.	Assessment 3
                                                        4.	Assessment 4
                                                        5.	Assessment 5
                                                        6.	Assessment 6
                                                        7.	Assessment 7
                                                        8.	Assessment 8
                                                        9.	Assessment 9
     3.1       Christiane Chan      Nov 07 2013    TTSD I#2811102- ORA-20001: FLEX-CONCAT LEN > IAPFLEN: N, MAXFLDLEN, 700
    3.2  Elango Pandurangan         Nov 13 2013  PEO Person type modification
    3.3        Christiane Chan      Feb 04 2014   INC0102683 - Fix for CR ntegration issue. We need to put quote on 692.
    3.4        Christiane Chan      May 12 2014   REQ0020334 - HireIQ enhancement - adding 4 new fields to HireIQ
                                                         1. HIQ_PACKAGE_ID
                                                         2. HIQ_RATING
                                                         3. HIQ_INTERVIEWER
                                                         4. HIQ_SCORES
    3.5        Christiane Chan      May 31 2014   REQ0037307 - Mexico enhancement - adding 4 new fields to MEX Integration
                                                         1. Nationality
                                                         2. Telephone - Home + Mobile
                                                         3. RFC
                                                         4. Contract Start Date
                                                         5. Adjusted Service Date
    3.6         Lalitha Nagarajan    June 1 2015   INC1082899 - If cpf_flag is null in Taleo,
                                                  insert Y  in Oracle cll table for Brazil
     4.0        Christiane Chan      Oct 31 2017   PRJTASK0007159 - Brazil enhancement: eSocial Requirements for Brazilian Payroll
                                                                    Adding new fields to BRZ Integration
                                                                    1. BirthTown
                                                                    2. Bairro -> Neighborhood
                                                                    3. Level of Education STUDYLEVEL
                                                                    4. Preferred Name
                                                                    5. Ethnicity
                                                                    6. Disability Indicator and Type
                                                                    7. Contact RelationShip
                                                                       1. Adding Father's Name
                                                                       2. Adding Mother's Name
                                                                    8. First Employment
                                                                    9. Retired
                                                                   10. Military Discharge
     5.0        Christiane Chan      May 17 2018  Motif India Integration BG -> 48558
                                                   1. India Address - Primary Address is required - Move in since is required -> Date Start
                                                   2. India Address - Mailing Address is required - Should we default Date Start to the starting date on this one
                                                   3. Residence Status where Lookup_type = 'IN_RESIDENTIAL_STATUS'
                                                   4. PAN Number - First 5 characters are letters, next four numbers, last 1 character.
                                                                   PAN, or permanent account number, is a unique 10-digit alphanumeric identity allotted to each taxpayer by the Income Tax Department under the supervision of the Central Board of Direct Taxes.
                                                                   It also serves as an identity proof. ... The PAN number remains unaffected by change of address throughout India.
                                                   5. Provident Fund Number - The EPF is created by the Employees Provident Fund Organization (EPFO) of India, a statutory body of the Indian Government under the Labour and Employment Ministry.
                                                   6. Aadar Number - 12 digits  Aadhaar is a 12-digit unique identification number issued by the Indian government to every individual resident of India. The Unique Identification Authority of India (UDAI),
                                                                     which functions under the Planning Commission of India, is responsible for managing Aadhaar numbers and Aadhaar identification cards.
                                                   7. UAN Number - 12 digits The UAN or the Universal Account number is a 12 digit unique number allotted to each member of Employee Provident Fund (EPF) which helps him to control all his EPF accounts.
                                                                   The UAN will be associated with an employee and will connect all his PF (Provident Fund) accounts across organizations. This number is issued by the Ministry of Labour and Employment,
                                                                   Government of India. If an individual changes his job, he will get a new PF account with the organization. This way, multiple PF account numbers will be allotted to an employee.
                                                                   Multiple PF account numbers is an area of concern as many employees report grievances related to transfer and withdrawal of PF amount.
                                                                   To counter this problem and to make the management of provident fund accounts easier, the concept of UAN was introduced
                                                                   The UAN is a single account number that will connect the multiple IDs associated with an employer.
                                                                   With UAN, an employee can connect all his EPFO accounts to make the process of PF withdrawal and transfer more easy.
                                                   8. Voter ID  - 3 or 4 alpha, 7-8 numeric (Example DMW3327806 )
                                                                  Voter ID (India) The Indian voter ID card is an identity document issued by the Election Commission of India which primarily serves as an identity proof for Indian citizens w
                                                                  hile casting votes in the country's municipal, state, and national elections. ... It is also known as Electoral Photo ID Card (EPIC).
                                                   9. Adding Father's Name and Mother's Name in Extra Person Information -> TTEC_IND_PARENTS_DETAILS
     6.0        Christiane Chan      Aug 10, 2018  REQ0535883 - Brazil Integration took place in 2013, and not sure why, the logic below indicates to CREATE_COSTING only if Business Group is different than Brazil.
                                                                Removing the comment on creating the BRZ Costing
     6.1        Christiane Chan      Feb 26, 2019  PRJ0011473 - Motif Project - Taleo DFF Mapping
                                                                Moving Name As On PAN 	 from: PER_INFORMATION18 To:ATTRIBUTE26
                                                                Moving Name As On Adhaar from: PER_INFORMATION19 To:ATTRIBUTE27
                                                                Moving Voter ID Number	 from: PER_INFORMATION20 To:ATTRIBUTE28
     6.2        Christiane Chan      Apr 30,2019  Enable India Salary
     6.3        Christiane Chan      Apr 30,2019  Adding Arbitration Agreement for US -> BG 325
     6.4        Christiane Chan      Sep 09,2019  INC5490384 - Canada rehire is raising API error due to missing ATTRIBUTE15 on update employee API
     6.5        Christiane Chan      Sep 10,2019  ALLCAP
     6.6        Vaitheghi            Oct 23,2019  STRY0045241 - Changes for BRZ - Address in ALLCAP and remove dots in RG Number
     6.7        Vaitheghi            Dec 05,2019  TASK1243934 - Changes for BRZ - Swapping of Father's/Mother's first and middle names
	 6.8        Arpita Shukla        Mar 31,2020  TASK1395286 - Populate CPF number in National identifier and add birthregion for BRZ
     7.0        Christiane Chan      Apr 10,2020  Restore the code from Mar 09,2020  Add Annual Tenure Pay ASS_ATTRIBUTE20 10 Characters to International BG -> 5054
     7.1        Christiane Chan      Apr 27,2020  fix for missing National Identifier on rehire
     7.2        Christiane Chan      May 14,2020  Adding ASS_ATTRIBUTE22  for Work Arrangement and ASS_ATTRIBUTE23 Work Arrangement Reason - These 2 DFF are Global Fields, will be used for all countries
     7.3        Christiane Chan  Nov 11,2020 Greece Integration BG -> 54749
                                                  Adding new field for Greece Integration:
                                                 1. Person'sTitle -   Example MR.,MS,MRS.,MISS
                                                 2. Adding Dependant and Parents detail to Extra Information Type -> GRC_DEPENDENTS_PARENTS_DETAILS - Required for Greece
                                                              Number of Children  - Required
                                                              Candidat Father's Name   - Required
                                                              Candidate Mother's Name   - Required
                                                 3. Adding Work Permit Information to Extra Information Type -> GRC_WORK_PERMITS- Optional for Greece
                                                              Work Permit -Optional
                                                              Work Permit Expiry Date-Optional
                                                 4. Adding Passport Details to Extra Information Type -> GRC_WORK_PERMITS- Optional for Greece
                                                              Passport Number -Optional
                                                              Passport Expiry Date -Optional
                                                 5. Adding OAED Details to Personal Analysis Flexfield (SIT) -> GRC_OAED_DETAILS - Required for Greece
                                                              Reference Note from OAED? - Required
                                                              Program part-financed by OAED - Required
                                                              Receiving Unemployment Benefit by OAED - Required
                                                 6. Adding Work Insurance Details to Personal Analysis Flexfield (SIT) -> GRC_WORK_INSURENCE_DETAILS - Required for Greece
                                                             Start of Experience - Required
                                                              Insured before or after 1993? - Required
                                                 7. Adding Greek Tax Authority Department (DOY)to Personal Analysis Flexfield (SIT) -> GRC_TAX_AUTHORITY_DEPT - Required for Greece
                                                             Tax Authority Department - Required
                                                 8. Adding Greece address Style
                                                 9. Enabling matchpoint and hireiq
   7.4        Rajesh Koneru   Dec 24,2020   INC8404423 Fixing Re-hire issue for India Business group
   7.5        Venkata Kovvuri Sep 14,2021   Modified the code to upload candidates from Taleo with out CPP validation
   7.6        Venkata Kovvuri Sep 17,2021   Reverted the 7.5 changes and modified CPP synonym to CPP external tables
   7.7        Venkata Kovvuri Nov 11,2021   TASK2764171 - Modified the below proceedures to populate the actual country in person address for INTL BG.
                                                1. Commented hard coded coutry to CR in import_new_hire proc (For new Hire)
                                                2. Added per_information_category to 'CR' in update_employee proc (For Rehire)
                                                3. Modified address_style to CR_GLB in update_address proc (For Rehire)
   7.8		  Rajesh Koneru   Nov 30,2021   INC10737518 - Modified the CPP election date and revocation dates to NULL.
   7.9        Venkata Kovvuri Nov 29, 2021  Modified the Update Assignment Proceedure to populate the Tech_Soln value in
											ASS_ATTRIBUTE24 in per_all_assignments_f table.
   8.0       Rajesh Koneru    Dec 08, 2021  Modified the code to populate the disabilty field for US.
   8.1       Venkata Kovvuri  Feb 02, 2022  Modified the code to populate citizenship value for PHL.
   8.2       Venkata Kovvuri  Feb 14, 2022  Modified the code to populate disabilty field for PHL.
   8.3       Venkata Kovvuri  Apr 04, 2022  Added logic to populate the MEX Fiscal values to Person SIT.
   8.4		 Venkata Kovvuri  May 25, 2022  Changes made to create SA employees
   8.5       Rajesh Koneru    May 27, 2022  Added logic to populate the Columbia Person SIT.
   8.6       Venkat Kollai    Nov 14, 2022  Australia new BG Integration.
   8.7       Venkat Kollai    Jan 30, 2023  Modified to include MEX_SODEXO_LOC field in ASS_ATTRIBUTE16 of per_all_assignments_f table.
   8.8       Venkat Kollai    Mar 16, 2023  Modified to load Nationality in People form.
   1.0	IXPRAVEEN(ARGANO)  14-july-2023		R12.2 Upgrade Remediation
   ***********************************************************************************/
   g_action_type   VARCHAR2 (25);

   -- declare global variables
   g_run_date                     CONSTANT DATE             := TRUNC (SYSDATE);
   g_oracle_start_date            CONSTANT DATE             := TO_DATE ('01-JAN-1950');
   g_oracle_end_date              CONSTANT DATE             := TO_DATE ('31-DEC-4712');
   --START R12.2 Upgrade Remediation
   /*g_module_name                  cust.ttec_error_handling.module_name%TYPE   := NULL;					-- Commented code by IXPRAVEEN-ARGANO,14-july-2023
   g_error_message                cust.ttec_error_handling.error_message%TYPE := NULL;
   g_success_flag                 VARCHAR2 (1);
   g_primary_column               cust.ttec_error_handling.reference1%TYPE  := NULL;
   g_secondary_column             cust.ttec_error_handling.reference1%TYPE  := NULL;
   g_label1                       cust.ttec_error_handling.label1%TYPE      := 'Candidate ID';
   g_label2                       cust.ttec_error_handling.label2%TYPE      := NULL;
   g_label3                       cust.ttec_error_handling.label3%TYPE      := NULL;
   g_employee_number              per_all_people_f.employee_number%TYPE;
   g_npw_number                   per_all_people_f.npw_number%TYPE;

   g_location_name                hr_locations.location_code%TYPE;
   g_recruiter_owner_employee_id  cust.ttec_error_handling.label15%TYPE;
   g_recruiter_email_address      cust.ttec_error_handling.reference15%TYPE;

   -- declare error handling variables
   c_application_code             cust.ttec_error_handling.application_code%TYPE := 'HR';
   c_interface                    cust.ttec_error_handling.INTERFACE%TYPE        := 'TALEO';
   c_program_name                 cust.ttec_error_handling.program_name%TYPE     := 'Ttec_Taleo_Interface';
   c_warning_status               cust.ttec_error_handling.status%TYPE           := 'WARNING';
   c_failure_status               cust.ttec_error_handling.status%TYPE           := 'FAILURE';*/
   g_module_name                  apps.ttec_error_handling.module_name%TYPE   := NULL;						--  code Added by IXPRAVEEN-ARGANO,   14-july-2023
   g_error_message                apps.ttec_error_handling.error_message%TYPE := NULL;
   g_success_flag                 VARCHAR2 (1);
   g_primary_column               apps.ttec_error_handling.reference1%TYPE  := NULL;
   g_secondary_column             apps.ttec_error_handling.reference1%TYPE  := NULL;
   g_label1                       apps.ttec_error_handling.label1%TYPE      := 'Candidate ID';
   g_label2                       apps.ttec_error_handling.label2%TYPE      := NULL;
   g_label3                       apps.ttec_error_handling.label3%TYPE      := NULL;
   g_employee_number              per_all_people_f.employee_number%TYPE;
   g_npw_number                   per_all_people_f.npw_number%TYPE;

   g_location_name                hr_locations.location_code%TYPE;
   g_recruiter_owner_employee_id  apps.ttec_error_handling.label15%TYPE;
   g_recruiter_email_address      apps.ttec_error_handling.reference15%TYPE;

   -- declare error handling variables
   c_application_code             apps.ttec_error_handling.application_code%TYPE := 'HR';
   c_interface                    apps.ttec_error_handling.INTERFACE%TYPE        := 'TALEO';
   c_program_name                 apps.ttec_error_handling.program_name%TYPE     := 'Ttec_Taleo_Interface';
   c_warning_status               apps.ttec_error_handling.status%TYPE           := 'WARNING';
   c_failure_status               apps.ttec_error_handling.status%TYPE           := 'FAILURE';

--END R12.2.12 Upgrade remediation
   l_grc_business_group_id            per_all_people_f.business_group_id%TYPE;
   L_PER_ADD_COUNT number:=0;
   L_CORR_ADD_COUNT number:=0;
   PL_COUNTRY_CODE VARCHAR2(10);

   --declare exceptions
   skip_record                    EXCEPTION;
   rehire_record                  EXCEPTION;
   active_record                  EXCEPTION;
   api_error                      EXCEPTION;

   --  Interface table Cursor

   CURSOR c_hire
   IS
      (SELECT
	    ROWID                             ,
        cand_id                         candidate_id,  --**
        business_group_id,              --**
        lastname                        last_name,
        mid                             middle_names,
        firstname                       first_name,
        preferredname                   preferredname, /* 4.0.4 */
        DISABILITY                      DISABILITY, /* 4.0.6 */
        DISABILITYTYPE                  DISABILITYTYPE, /* 4.0.6 */
        FLASTNAME                       FLASTNAME,   /* 4.0.7.1 */
        FMIDDLENAME                     FMIDDLENAME, /* 4.0.7.1 */
        FFIRSTNAME                      FFIRSTNAME,  /* 4.0.7.1 */
        MLASTNAME                       MLASTNAME,   /* 4.0.7.2 */
        MMIDDLENAME                     MMIDDLENAME, /* 4.0.7.2 */
        MFIRSTNAME                      MFIRSTNAME,  /* 4.0.7.2 */
        FIRSTEMPLOYMENT                 FIRSTEMPLOYMENT, /* 4.0.8 */
        RETIRED                         RETIRED, /* 4.0.9 */
        RETIREDCODE                     RETIREDCODE, /* 4.0.9 */
        RETIREMENTDATE                  RETIREMENTDATE, /* 4.0.9 */
        MILITARYDISCHARGE               MILITARYDISCHARGE, /* 4.0.10 */
        email                           email,
        address                         address_line1,
        address2                        address_line2,
        city                            city,
		county                          county,
        zipcode                         postal_code,
        homephone                       homephone,
        workphone                       workphone,
        mobilephone                     mobilephone,
        ssnumber                        national_identifier,
        birthdaydate                    date_of_birth,
        --country,
        countrycode                     country_code,
        stateprovincecode               state,
        eeo12_genderid                  sex,
        eeo12veteranid                  veteran_id,
        -- ADDED FOR ZA INTEGRATION
        eeo12disabledveteranid          disabled_veteran_id,
        studylevel                      education_level,
        --
        eeo1raceethnicityid             ethnicity,
        /*Version 1.6.2 US Ethnic enhancement*/
        ethnic_disclosed                ethnic_disclosed,
        /*End Version 1.6.2*/
        departmentnumber                organization_id,
        hiringmanageremployeeID         supervisor_id,
        reqjobcode                      job_id,
        offeractualstart                start_date,
        offerstockpackage               stock_options,
        marital_status_US               marital_status_US,
        marital_status_PH               marital_status_PH,
        --reqclientprogram,
		client                          client_code,
		clientdesc                      client_desc,
		program                         program,
		programdesc                     program_desc,
		project                         project,
		projectdesc                     project_desc,
		payrollid                       payroll_id,
		greid                           gre_id,
		setofbooksid                    set_of_books_id,
		expenseaccountid                expense_account_id,
        reqassigcat                     assignment_category_code,
        reqproblength                   probation_length,
        reqprobationunits               probation_units,
        reqprobenddate                  probation_end_date,
        reqworkinghours                 normal_hours,
        reqfrequency                    frequency,
        reqgradeid                      grade_id,
        reqpeoplegroup                  people_group_id,
		reqworking_home                 working_at_home_flag,
        offer_salary_change_value       salary,
        offer_salary_basis              salary_basis_id,
        empl_is_rehire,                 --    NUMBER, --  ** Y or blank
        location_id                     location_id,
        --actual_start_date start_date,
        --req_salary_basis_id,
        timecard_required               timecard_required,
		recruiterowneremployeeid        recruiter_owner_employee_id,
		recruter_emailaddress           recruiter_email_address,
		nationality                     nationality,
		legacy_employee_number          legacy_employee_number,
		religion                        religion,
		employee_category               employee_category,
		review_salary                   review_salary,
		review_salary_frequency         review_salary_frequency,
		review_performance              review_performance,
		review_performance_frequency    review_performance_frequency,
        sys_per_type                    sys_per_type,
        person_type                     person_type,
        rate_type                       rate_type,
        agency_name                     agency_name,
        rate_id                         rate_id,
        fec_feedervalue                 fec_feedervalue,
        /* Version 1.5 - Argentina Integration */
        addressdistrict                 addressdistrict,
        addressneighborhood             addressneighborhood,
        addressmunicipality             addressmunicipality,
        socialsecurityid                socialsecurityid,
        birthcountry                    birthcountry,
        sstype                          sstype,
        unionaffiliation                unionaffiliation,
        industry                        industry,
        stateprovincedes                stateprovincedes,
        /* End of Version 1.5 */
        /* Version 1.6.1 - Mexico Integration */
        birthregion                     birthregion,
        birthtown                       birthtown,
        birthstate                      birthstate,
        maternalname                    maternalname,
        ss_salary_type                  ss_salary_type,
        contract_type                   contract_type,
        shift                           shift,
        workforce                       workforce,
        contract_start_dt               contract_start_dt,
        /* End of Version 1.6.1 */
        /* Version 1.7 - Costa Rica Integration */
        Language_Differential           LanguageDifferential,
        /* End of Version 1.7 */
       /* Version 1.8 --  additional requirement for ZA Integration */
       mp_source,
       mp_source_type,
       mp_batteryname,
       mp_batterylevel,
       mp_servicesimulation,
       mp_basiccomputerskills,
       mp_sales,
       mp_grammar,
       mp_adaptechsupport,
       mp_matrix,
       mp_fit,
       mp_ispsupport,
       mp_clt_assessment,
       mp_voice_score,
       mp_test_id,
       mp_listen,
       mp_recruiter_id,
       MP_CALLSIMULATIONADMINRECORDID, /* V 2.8 */
       MP_CALLSIMULATIONRESULTS,  /* V 2.8 */
       MP_CIWAdministrator,  /* V 2.8 */
       MP_CIWARESULT,        /* V 2.8 */
       MP_Assessment_1,      /* V 3.0 */
       MP_Assessment_2,      /* V 3.0 */
       MP_Assessment_3,      /* V 3.0 */
       MP_Assessment_4,      /* V 3.0 */
       MP_Assessment_5,      /* V 3.0 */
       MP_Assessment_6,      /* V 3.0 */
       MP_Assessment_7,      /* V 3.0 */
       MP_Assessment_8,      /* V 3.0 */
       MP_Assessment_9,      /* V 3.0 */
       HIQ_PACKAGE_ID,  /* Version 3.4 */
       HIQ_RATING,      /* Version 3.4 */
       HIQ_INTERVIEWER, /* Version 3.4 */
       HIQ_SCORES,      /* Version 3.4 */
       RFC_ID,   /* 3.5.3 */
        VisaExpirationDate             VisaExpirationDate,
        /*  --2.6 BRZ TALEO INTEGRATION CLL FIELDS                     */
        CPF_NUMBER ,
        CTPS_NUMBER  ,
        CTPS_ISSUE_DATE  ,
         CTPSSerialNumber ,
        PIS  ,
       PISBankNumber ,
      PISIssueDate,
      PISProgramType ,
      RGExpeditingDate ,
     RGExpeditorEntity ,
     RGLocation ,
     RGNumber ,
     RGState,
     VoterRegistrationCard,
     VRCSession ,
    VRCState ,
    VRCZone ,
    cpf_flag,    -- 2.6
    prg_flag,       -- v2.9
       /* End Version 1.8*/
       gl_location_override, -- Version 2.0
    /* Version 5.0 - Motif India Integration */
    RESIDENTSTATUS		RESIDENTSTATUS,
    LIVEINADDRSINCE		LIVEINADDRSINCE,
    PANCARDNUMBER		PANCARDNUMBER,
    PANCARDNAME		PANCARDNAME,
    ADHARCARDNUMBER	ADHARCARDNUMBER,
    ADHARCARDNAME		ADHARCARDNAME,
    VOTERID			VOTERID,
    EPFNUMBER		EPFNUMBER,
    UANNUMBER		UANNUMBER,
    CORRESPADDRESS	CORRESPADDRESS,
    CORRESPADDRESS2	CORRESPADDRESS2,
    CORRESPCITY		CORRESPCITY,
    CORRESPSTATE	CORRESPSTATE,
    CORRESPZIPCODE	CORRESPZIPCODE,
    CORRESPCOUNTRYCODE CORRESPCOUNTRYCODE,
    /* Version 5.0 - Motif India Integration */
    ARBITRATION_AGREEMENT ARBITRATION_AGREEMENT, /* 6.3 */
    ANNUALTENUREPAY ANNUALTENUREPAY, /* 7.0 */
    WORK_ARRANGEMENT WORK_ARRANGEMENT, /* 7.2 */
    WORK_ARRANGEMENT_REASON WORK_ARRANGEMENT_REASON, /* 7.2 */
	TITLE	,	/* 7.3 */
	NUMBER_DEPENDENT_CHILD	,	/* 7.3 */
	EXPERIENCE_START_DATE	,	/* 7.3 */
	INSURED_BEFORE_AFTER_1993	,	/* 7.3 */
	REFERENCE_NOTE_FROM_OAED	,	/* 7.3 */
	PROGRAM_PART_FINANCED_BY_OAED	,	/* 7.3 */
	RECEIVING_UNEMPL_BEN_BY_OAED	,	/* 7.3 */
	WORK_PERMIT_NUMBER	,	/* 7.3 */
	WORK_PERMIT_EXPIRY_DATE	,	/* 7.3 */
	PASSPORT_NUMBER	,	/* 7.3 */
	PASSPORT_EXPIRY_DATE	,	/* 7.3 */
	TAX_AUTHORITY_DEPARTMENT,		/* 7.3 */
        POLAND_INDUSTRY_EXPERIENCE ,
        PL_REMAINING_BAL,
        DEPARTMENTNUMBER,
        AMKA ,
      AMA,
  GREEK_FIRST_NAME,
  GREEK_LAST_NAME,
  WORKING_DAY_WEEK,
  WORKING_ON_HOLIDAYS,
  EE_ENDDATE ,
  START_TIME ,
  OAED_SPECIALITY_CODE,
  ATTENDANCE_MODE,
  IDENTITIY_CARD_NUM,
  BULG_EMP_CODE,
  TECH_SOLN,          -- Added as part of 7.9
  CITIZENSHIP,        -- Added as part of 8.1
  FISCAL_NAME,          -- Added as part of 8.3
  FISCAL_ADD_ZIP,       -- Added as part of 8.3
  FISCAL_REGIME_TYPE,    -- Added as part of 8.3
  TAX_NUMBER,             -- Added as part of 8.4
  CSI_ID_TYPE , 			-- Added as part of 8.5
  --CSI_EMPLOYEE_ID , 		-- Added as part of 8.5
  CSI_TAX_NUM , 			-- Added as part of 8.5
  CSI_FOREIGNER_NUM ,		-- Added as part of 8.5
  CSI_PASSPORT_NUM , 		-- Added as part of 8.5
  CSI_PASSPORT_COUNTRY,     -- Added as part of 8.5
  CSI_ID_ISSUE_CITY , 		-- Added as part of 8.5
  CSI_ID_ISSUE_STATE , 		-- Added as part of 8.5
  CSI_EMPLOYMENT_CONTRACT , -- Added as part of 8.5
  Neighborhood , 			-- Added as part of 8.5
  Estrato , 				-- Added as part of 8.5
  Department_Code , 		-- Added as part of 8.5
  Municipality_Code , 		-- Added as part of 8.5
  NIT_EPS , 				-- Added as part of 8.5
  NIT_AFP,  				-- Added as part of 8.5
  GOV_JOB_OCCUPATION_CODE, 	-- Added as part of 8.5
  Workers_Activity_Code,		-- Added as part of 8.5
  CSI_CONTRACT_TYPE, 	-- Added as part of 8.5
  CSI_WEEKLY_DAYS,       -- Added as part of 8.5
  CSI_ISSUE_DATE,    -- Added as part of 8.5
  MEX_SODEXO_LOC     --Added as part of 8.7

    --FROM cust.ttec_taleo_stage		-- Commented code by IXPRAVEEN-ARGANO,14-july-2023
    FROM apps.ttec_taleo_stage          --  code Added by IXPRAVEEN-ARGANO,   14-july-2023
    WHERE emp_val_err = 0 --and CAND_ID=16696966
          --empl_is_rehire = 1
     AND  oracle_load  = 0
     AND  oracle_load_sucess = 0
     ) ;

    /*************************************************************************************************************
    -- PROCEDURE print_line
    -- Author: Ibrahim Konak
    -- Date:  Feb 26 2007
    -- Parameters: iv_data --> Text to be printed out in the output file.
    -- Description: This procedure standardizes concurrent program output calls.
    **************************************************************************************************************/
    PROCEDURE print_line (iv_data IN VARCHAR2)
    IS
    BEGIN
      Fnd_File.put_line (Fnd_File.output, iv_data);

    END;   -- print_line

    /*************************************************************************************************************
    -- PROCEDURE log_error
    -- Author: Ibrahim Konak
    -- Date:  Feb 26 2007
    -- Parameters: None.
    -- Description: This procedure standardizes concurrent program exception handling.
    **************************************************************************************************************/
    PROCEDURE log_error

    IS
    BEGIN
      --cust.ttec_process_error (			-- Commented code by IXPRAVEEN-ARGANO,14-july-2023
      apps.ttec_process_error (             --  code Added by IXPRAVEEN-ARGANO,   14-july-2023
	       application_code => c_application_code,
           INTERFACE        => c_interface,
           program_name     => c_program_name,
           module_name      => g_module_name,
           status           => c_warning_status,
           error_code       => NULL,
           error_message    => g_error_message,
           label1           => g_label1,
           reference1       => g_primary_column,
           label2           => g_label2,
           reference2       => g_secondary_column,
		   label3           => g_label3,
           reference3       => g_location_name,
		   label15		    => g_recruiter_owner_employee_id,
           reference15      => g_recruiter_email_address );

      print_line (   RPAD (NVL (g_location_name, ' '), 20)
                  || ' '
                  || RPAD (NVL (g_primary_column, ' '), 8)
                  || ' '
                  || RPAD (NVL (g_label2, ' '), 17)
                  || ' '
                  || RPAD (NVL (g_secondary_column, ' '), 20)
                  || ' '
                  || NVL (g_error_message, ' ')
                 );

      DBMS_OUTPUT.PUT_LINE (  SUBSTR( g_location_name
                            || ' '

                            || g_primary_column
                            || ' '
                            --|| g_label2
                            --|| ' '
                            --|| g_secondary_column
                            --|| ' '
                            || g_error_message, 1, 200)
                           );
    END;   -- log error

    /*************************************************************************************************************
    -- PROCEDURE update_interfase
    -- Author: Ibrahim Konak
    -- Date:  Feb 26 2007
    -- Parameters:  p_status            --> Status of the candidate in the staging table.
                    p_rowid             --> ROWID from the staging table.
                    p_person_id         --> Candidate's person id.
                    p_employee_number   --> Candidate's employee_number.
                    p_npw_number        -->
    -- Description: This procedure updates the taleo interface table with the latest status..
    **************************************************************************************************************/
    PROCEDURE update_interface (
      p_status            IN   VARCHAR2,
      p_rowid             IN   UROWID,
      p_person_id         IN   NUMBER,
      p_employee_number   IN   VARCHAR2,
      p_npw_number        IN   VARCHAR2
    )
    IS
    BEGIN
      g_module_name := 'update_interface ';

      --UPDATE cust.TTEC_TALEO_STAGE			-- Commented code by IXPRAVEEN-ARGANO,14-july-2023
      UPDATE apps.TTEC_TALEO_STAGE              --  code Added by IXPRAVEEN-ARGANO,   14-july-2023
         SET employee_number = p_employee_number,
             npw_number      = p_npw_number,
             person_id = p_person_id,
             oracle_load  = 1,
             oracle_load_sucess = p_status,
             last_update_date = SYSDATE,
             --last_updated_by = Fnd_Global.user_id,
             concurrent_update_id = Fnd_Global.conc_request_id
       WHERE ROWID = p_rowid;


    EXCEPTION
      WHEN OTHERS
      THEN
         g_error_message := 'Warning: While updating interface' || SQLERRM;
         g_label2 := 'Candidate';

         g_secondary_column := g_primary_column;
         log_error;
    END;

    /*************************************************************************************************************
    -- PROCEDURE get_rehire_person
    -- Author: Ibrahim Konak
    -- Date:   Feb 26 2007
    -- Parameters:
    -- Description: This procedure provides Person Status of the person. If the Person is active record needs to
    --              be skipped. If the person is terminated status indicates rehire and return  if the person is
    --              rehire-eligible or not. If the person is not in the system create the new hire record.
    -- Modification log:
    -- Version    Developer              Date         Description
    -- ---        ----------------    -----------     --------------------------------
    -- 1.3.2      MLagostena          Nov 05 2008     Modified to handle UK rehires (which allow null NINS) as PHL rehires.
    **************************************************************************************************************/
    PROCEDURE get_rehire_person(
      p_national_identifier         IN       VARCHAR2,
      p_business_group_id           IN       NUMBER,
      p_start_date                  IN       DATE,
      p_first_name                  IN       VARCHAR2,
      p_last_name                   IN       VARCHAR2,
      p_middle_names                IN       VARCHAR2,
      p_date_of_birth               IN       DATE,
      p_sex                         IN       VARCHAR2,
      p_cpf_number                  IN       NUMBER,
      p_cpf_flag                    IN       VARCHAR2,
      p_prg_flag                    IN       VARCHAR2,
      p_person_id                   OUT      NUMBER,
      p_per_object_version_number   OUT      NUMBER,
      p_employee_number             OUT      VARCHAR2,
      p_leav_reason                 OUT      VARCHAR2,
      p_rehire_eligible             OUT      VARCHAR2,
      p_final_process_date          OUT      DATE,
      p_period_of_service_id        OUT      NUMBER,
      p_ppos_ovn                    OUT      NUMBER,
      p_full_name                   OUT      VARCHAR2
    )
    IS
      l_person_id                   per_all_people_f.person_id%TYPE;
      l_actual_termination_date     per_periods_of_service.actual_termination_date%TYPE;
      l_final_process_date          per_periods_of_service.final_process_date%TYPE;
      l_last_standard_process_date  per_periods_of_service.last_standard_process_date%TYPE;
      l_status                      VARCHAR2 (25);
      l_own_cpf_flag                varchar2(1);


      CURSOR c_status_us_ca
      IS
         SELECT papf.person_id, ppos.actual_termination_date,
                ppos.last_standard_process_date,
                ppos.final_process_date, papf.person_id,
                papf.object_version_number, papf.employee_number,
                ppos.leaving_reason, ppos.attribute9,
                ppos.final_process_date, ppos.period_of_service_id,
                ppos.object_version_number, papf.full_name
           FROM per_all_people_f papf,
                per_all_assignments_f paaf,
                per_periods_of_service ppos
          WHERE REPLACE(REPLACE(papf.national_identifier,' '),'-')
                          = p_national_identifier
            AND papf.business_group_id = p_business_group_id
            AND papf.person_id = paaf.person_id
            --AND papf.employee_number IN (1027119, 2017096)
            AND paaf.assignment_type = 'E'
            AND paaf.primary_flag = 'Y'
            AND paaf.period_of_service_id = ppos.period_of_service_id
            AND paaf.effective_start_date =
                   (SELECT MAX (paaf1.effective_start_date)
                      FROM per_all_assignments_f paaf1
                     WHERE paaf1.person_id = papf.person_id
                       AND paaf.assignment_type = 'E'
                       AND paaf.primary_flag = 'Y')
            AND papf.effective_start_date =
                                    (SELECT MAX (papf1.effective_start_date)
                                       FROM per_all_people_f papf1
                                      WHERE papf1.person_id = papf.person_id);


      CURSOR c_status_phl
      IS
         SELECT papf.person_id, ppos.actual_termination_date,
                 ppos.last_standard_process_date,
                ppos.final_process_date, papf.person_id,
                papf.object_version_number, papf.employee_number,
                ppos.leaving_reason, ppos.attribute9, ppos.final_process_date,
                ppos.period_of_service_id, ppos.object_version_number,
                papf.full_name
           FROM per_all_people_f papf,
                per_all_assignments_f paaf,
                per_periods_of_service ppos
          WHERE papf.sex = NVL (p_sex, papf.sex)
            AND papf.date_of_birth = NVL (p_date_of_birth, papf.date_of_birth)
            AND UPPER(papf.first_name) = NVL (UPPER(p_first_name), papf.first_name)
            AND UPPER(papf.last_name) = NVL (UPPER(p_last_name), papf.last_name)
            --AND papf.middle_names = NVL (p_middle_names, papf.middle_names)
            -- The line above was commented to avoid NULL = NULL comparissons)
            AND NVL (UPPER (papf.middle_names), '%') =
                                 NVL (UPPER (p_middle_names),'%')
            AND papf.person_id = paaf.person_id
            AND paaf.assignment_type = 'E'
            AND paaf.primary_flag = 'Y'
            AND paaf.period_of_service_id = ppos.period_of_service_id
            AND paaf.effective_start_date =
                   (SELECT MAX (paaf1.effective_start_date)
                      FROM per_all_assignments_f paaf1
                     WHERE paaf1.person_id = paaf.person_id
                       AND paaf.assignment_type = 'E'
                       AND paaf.primary_flag = 'Y')
            AND papf.effective_start_date =
                                    (SELECT MAX (papf1.effective_start_date)
                                       FROM per_all_people_f papf1
                                      WHERE papf1.person_id = papf.person_id);
  CURSOR c_status_brz   -- 2.6 brz
      IS
         SELECT papf.person_id, ppos.actual_termination_date,
                ppos.last_standard_process_date,
                ppos.final_process_date, papf.person_id,
                papf.object_version_number, papf.employee_number,
                ppos.leaving_reason, ppos.attribute9,
                ppos.final_process_date, ppos.period_of_service_id,
                ppos.object_version_number, papf.full_name,cpd.own_cpf_flag
           FROM per_all_people_f papf,
                per_all_assignments_f paaf,
                apps.cll_f038_person_data cpd,
                per_periods_of_service ppos
          WHERE
                   papf.business_group_id = p_business_group_id
            AND papf.person_id = paaf.person_id
            and cpd.person_id = paaf.person_id
            and cpd.own_cpf_flag = p_cpf_flag
            and cpd.cpf_number = p_cpf_number
            --AND papf.employee_number IN (1027119, 2017096)
            AND paaf.assignment_type = 'E'
            AND paaf.primary_flag = 'Y'
            AND paaf.period_of_service_id = ppos.period_of_service_id
            AND paaf.effective_start_date =
                   (SELECT MAX (paaf1.effective_start_date)
                      FROM per_all_assignments_f paaf1
                     WHERE paaf1.person_id = papf.person_id
                       AND paaf.assignment_type = 'E'
                       AND paaf.primary_flag = 'Y')
            AND papf.effective_start_date =
                                    (SELECT MAX (papf1.effective_start_date)
                                       FROM per_all_people_f papf1
                                      WHERE papf1.person_id = papf.person_id);
      CURSOR c_status_prg       -- v2.9
      IS
         SELECT papf.person_id, ppos.actual_termination_date,
                 ppos.last_standard_process_date,
                ppos.final_process_date, papf.person_id,
                papf.object_version_number, papf.employee_number,
                ppos.leaving_reason, ppos.attribute9, ppos.final_process_date,
                ppos.period_of_service_id, ppos.object_version_number,
                papf.full_name
           FROM per_all_people_f papf,
                per_all_assignments_f paaf,
                hr_locations_all hla,
                per_periods_of_service ppos
          WHERE papf.sex = NVL (p_sex, papf.sex)
            AND papf.date_of_birth = NVL (p_date_of_birth, papf.date_of_birth)
            AND UPPER(papf.first_name) = NVL (UPPER(p_first_name), papf.first_name)
            AND UPPER(papf.last_name) = NVL (UPPER(p_last_name), papf.last_name)
            AND paaf.location_id = hla.location_id
            AND hla.location_code LIKE '%PRG%'
            --AND papf.middle_names = NVL (p_middle_names, papf.middle_names)
            -- The line above was commented to avoid NULL = NULL comparissons)
            AND NVL (UPPER (papf.middle_names), '%') =
                                 NVL (UPPER (p_middle_names),'%')
            AND papf.person_id = paaf.person_id
            AND paaf.assignment_type = 'E'
            AND paaf.primary_flag = 'Y'
            AND paaf.period_of_service_id = ppos.period_of_service_id
            AND paaf.effective_start_date =
                   (SELECT MAX (paaf1.effective_start_date)
                      FROM per_all_assignments_f paaf1
                     WHERE paaf1.person_id = paaf.person_id
                       AND paaf.assignment_type = 'E'
                       AND paaf.primary_flag = 'Y')
            AND papf.effective_start_date =
                                    (SELECT MAX (papf1.effective_start_date)
                                       FROM per_all_people_f papf1
                                      WHERE papf1.person_id = papf.person_id);

    BEGIN
      g_module_name := 'get_rehire_person_status';


      IF p_business_group_id in (1517, 1761)    -- to allow rehire of employees with null SSN (PHL/UK) (MLagostena -Nov 05 2008)
         AND p_national_identifier IS NULL
      THEN
         --check by name
         OPEN c_status_phl;

         FETCH c_status_phl
          INTO l_person_id, l_actual_termination_date, l_LAST_STANDARD_PROCESS_DATE,
               l_final_process_date,
               p_person_id, p_per_object_version_number, p_employee_number,
               p_leav_reason, p_rehire_eligible, p_final_process_date,
               p_period_of_service_id, p_ppos_ovn, p_full_name;

         IF c_status_phl%NOTFOUND
         THEN
            l_status := 'CREATE';
         END IF;

         CLOSE c_status_phl;
      ELSIF p_business_group_id in (5054) AND p_prg_flag = 'Y'      -- v2.9
        THEN
         OPEN c_status_prg;

         FETCH c_status_prg
          INTO l_person_id, l_actual_termination_date, l_last_standard_process_date,
               l_final_process_date,
               p_person_id, p_per_object_version_number, p_employee_number,
               p_leav_reason, p_rehire_eligible, p_final_process_date,
               p_period_of_service_id, p_ppos_ovn, p_full_name;

         IF c_status_prg%NOTFOUND
         THEN
            l_status := 'CREATE';
         END IF;

         CLOSE c_status_prg;
      ELSIF p_business_group_id = 1631 AND p_cpf_number IS NOT NULL   -- 2.6 brz
       THEN
        OPEN c_status_brz ;
        FETCH c_status_brz
        INTO
          l_person_id, l_actual_termination_date,l_last_standard_process_date,
               l_final_process_date,
               p_person_id, p_per_object_version_number, p_employee_number,
               p_leav_reason, p_rehire_eligible, p_final_process_date,
               p_period_of_service_id, p_ppos_ovn, p_full_name, l_own_cpf_flag;
         IF c_status_brz%NOTFOUND
         THEN
            l_status := 'CREATE';
            fnd_file.put_line(fnd_file.log, 'Entered 2-'|| l_own_cpf_flag) ;
         END IF;

         CLOSE c_status_brz ;
      ELSE
         --check by national_identifier
         OPEN c_status_us_ca;

         FETCH c_status_us_ca
          INTO l_person_id, l_actual_termination_date,l_LAST_STANDARD_PROCESS_DATE,
               l_final_process_date,
               p_person_id, p_per_object_version_number, p_employee_number,
               p_leav_reason, p_rehire_eligible, p_final_process_date,
               p_period_of_service_id, p_ppos_ovn, p_full_name;
         DBMS_OUTPUT.PUT_LINE ('Person ID:'||p_person_id);
         DBMS_OUTPUT.PUT_LINE ('Actual termination date:'||l_actual_termination_date);

         IF c_status_us_ca%NOTFOUND
         THEN
            l_status := 'CREATE';
         END IF;

         CLOSE c_status_us_ca;
      END IF;


      IF l_status = 'CREATE'
      THEN
      fnd_file.put_line(fnd_file.log, 'Entered 3 -'|| l_own_cpf_flag) ;
         g_error_message := 'New employee cannot be Rehired.';
         IF p_business_group_id in (1517,1761) -- to allow rehire of employees with null SSN (PHL/UK) (MLagostena -Nov 05 2008)
          AND p_national_identifier IS NULL
         THEN
            g_label2 := 'Name';
            g_secondary_column :=
                           SUBSTR (p_first_name || ' ' || p_last_name, 1, 15);
        ELSIF p_business_group_id = 1631 AND P_CPF_NUMBER IS NOT NULL THEN   -- 2.6
        fnd_file.put_line(fnd_file.log, 'Entered 4') ;
             g_label2 := 'CPF_NUMBER';
             g_secondary_column := P_CPF_NUMBER;
         ELSE
            g_label2 := 'National Identifier:';
            g_secondary_column := p_national_identifier;
         END IF;
         RAISE skip_record;
      END IF;

      DBMS_OUTPUT.PUT_LINE ('Final process date:        '||l_final_process_date);
      DBMS_OUTPUT.PUT_LINE ('Last standard process date:'||l_last_standard_process_date);
      DBMS_OUTPUT.PUT_LINE ('Actual termination date:   '||l_actual_termination_date);


      IF NVL (l_final_process_date, p_start_date) <= p_start_date
         --for final process API
         AND l_actual_termination_date <= p_start_date - 1
         AND NVL (l_last_standard_process_date, p_start_date -1) <= p_start_date - 1
         --can rehire on the same day emp was termed
      THEN
         l_status := 'REHIRE';
         fnd_file.put_line(fnd_file.log, 'Entered 6') ;
      ELSE
         IF p_business_group_id in (1517,1761) -- to allow rehire of employees with null SSN (PHL/UK) (MLagostena -Nov 05 2008)
            AND p_national_identifier IS NULL
         THEN
            g_label2 := 'Name';
            g_secondary_column :=
                           SUBSTR (p_first_name || ' ' || p_last_name, 1, 15);
     ELSIF p_business_group_id = 1631 AND P_CPF_NUMBER IS NOT NULL THEN   -- 2.6 BRZ
             g_label2 := 'CPF_NUMBER';
             g_secondary_column := P_CPF_NUMBER;
         ELSE
            g_label2 := 'National Identifier:';
            g_secondary_column := p_national_identifier;
         END IF;
         g_error_message := 'Incomplete or Future Term cannot be Rehired .';
         RAISE skip_record;

      END IF;

    EXCEPTION
      WHEN OTHERS
      THEN
         g_error_message := 'Error while getting Rehire Person Status:' || g_error_message  ||SQLERRM;
         IF p_business_group_id in (1517, 1761) -- to allow rehire of employees with null SSN (PHL/UK) (MLagostena -Nov 05 2008)
            AND p_national_identifier IS NULL
         THEN
            g_label2 := 'Name';
            g_secondary_column :=
                           SUBSTR (p_first_name || ' ' || p_last_name, 1, 15);
     ELSIF p_business_group_id = 1631 AND P_CPF_NUMBER IS NOT NULL THEN   -- 2.6
             g_label2 := 'CPF_NUMBER';
             g_secondary_column := P_CPF_NUMBER;
         ELSE
            g_label2 := 'National Identifier:';
            g_secondary_column := p_national_identifier;
         END IF;

         RAISE skip_record;
    END;
    /*************************************************************************************************************
    -- PROCEDURE get_lookup_code
    -- Author: Ibrahim Konak
    -- Date:  Feb 26 2007
    -- Parameters:
    -- Description: This procedure provides Lookup Code for Gender.
    **************************************************************************************************************/
    FUNCTION get_lookup_code (p_lookup_type IN VARCHAR2, p_meaning IN VARCHAR2)
      RETURN VARCHAR2
    IS
      l_lookup_code   hr_lookups.lookup_code%TYPE;
    BEGIN
      g_module_name := 'get_lookup_code';

      SELECT lookup_code
        INTO l_lookup_code
        FROM hr_lookups
       WHERE lookup_type = p_lookup_type AND meaning = p_meaning;


      RETURN l_lookup_code;
    EXCEPTION
      WHEN OTHERS
      THEN
         g_error_message :=
                          'Error invalid lookup:' || p_lookup_type || SQLERRM;
         g_label2 := 'Lookup:' || p_lookup_type;
         g_secondary_column := p_meaning;
         RAISE skip_record;
    END;

    /*************************************************************************************************************
    -- PROCEDURE get_person_type
    -- Author: Ibrahim Konak
    -- Date:  Feb 26 2007
    -- Parameters:
    -- Description: This procedure provides Employee Person Type ID.
    **************************************************************************************************************/
    FUNCTION get_person_type (p_business_group_id IN NUMBER)
      RETURN NUMBER
    IS
      CURSOR c_person
      IS
         (SELECT person_type_id
            FROM per_person_types
           WHERE system_person_type = 'EMP'
             AND user_person_type = 'Employee'
             AND business_group_id = p_business_group_id);

      l_person_type_id   NUMBER := NULL;

    BEGIN
      OPEN c_person;

      FETCH c_person
       INTO l_person_type_id;

      CLOSE c_person;

      RETURN l_person_type_id;
    END;
    /*************************************************************************************************************
    -- PROCEDURE get_work_schedule
    -- Author: Ibrahim Konak
    -- Date:  Feb 26 2007
    -- Parameters:
    -- Description: This procedure provides Work Schedule.
    **************************************************************************************************************/
    FUNCTION get_work_schedule (p_organization_id IN NUMBER)
      RETURN NUMBER
    IS
      CURSOR c_work_schedule(p_work_schedule IN VARCHAR2)
	      IS
         (SELECT org_information1
            FROM hr_organization_information
            WHERE org_information_context = p_work_schedule
             AND organization_id = p_organization_id);

      l_work_schedule_id   NUMBER := NULL;

    BEGIN
        IF p_organization_id = 325 THEN

          --OPEN c_work_schedule('Work Schedule');
           --FETCH c_work_schedule
           --INTO l_work_schedule_id;
          --CLOSE c_work_schedule;
	        l_work_schedule_id := 64;

	    ELSIF p_organization_id = 326 THEN

          --OPEN c_work_schedule('Canadian Work Schedule');
           --FETCH c_work_schedule
           --INTO l_work_schedule_id;
          --CLOSE c_work_schedule;
            l_work_schedule_id := 47;

	    END IF;

        RETURN l_work_schedule_id;

    EXCEPTION
        WHEN OTHERS THEN
	        RETURN NULL;
    END;

    /*************************************************************************************************************
    -- PROCEDURE format_national_identifier
    -- Author: Ibrahim Konak
    -- Date:  Feb 26 2007
    -- Parameters:
    -- Description: This procedure formats national identifier for US, Canadian and Phillipines employees.
    **************************************************************************************************************/
    FUNCTION format_national_identifier (
      p_national_identifier   IN   VARCHAR2,
      p_business_group_id     IN   NUMBER

    )
      RETURN VARCHAR2
    IS
      l_national_identifier   per_all_people_f.national_identifier%TYPE;

    BEGIN
      g_module_name         := 'format_national_identifier';
      l_national_identifier := p_national_identifier;

      IF l_national_identifier IS NOT NULL
      THEN                                 -- national identifier can be null
         IF p_business_group_id = 325
         THEN
            l_national_identifier := REPLACE (l_national_identifier, '-');

            l_national_identifier :=
                  SUBSTR (l_national_identifier, 1, 3)
               || '-'
               || SUBSTR (l_national_identifier, 4, 2)
               || '-'
               || SUBSTR (l_national_identifier, 6, 4);

         ELSIF p_business_group_id = 326
         THEN
            l_national_identifier := REPLACE (l_national_identifier, '-');
            l_national_identifier := REPLACE (l_national_identifier, ' ');
            l_national_identifier :=
                  SUBSTR (l_national_identifier, 1, 3)
               || ' '
               || SUBSTR (l_national_identifier, 4, 3)
               || ' '
               || SUBSTR (l_national_identifier, 7, 3);

         -- For Philiphines
         ELSIF p_business_group_id = 1517
         THEN
            l_national_identifier := REPLACE (l_national_identifier, '-');
            l_national_identifier := REPLACE (l_national_identifier, ' ');
            --l_national_identifier := SUBSTR(l_national_identifier,1,3)||' '||SUBSTR(l_national_identifier,4,3)||' '||SUBSTR(l_national_identifier,7,4);
            l_national_identifier :=
                  SUBSTR (l_national_identifier, 1, 2)
               || '-'
               || SUBSTR (l_national_identifier, 3, 7)

               || '-'
               || SUBSTR (l_national_identifier, 10, 1);
         END IF;
      END IF;

      RETURN l_national_identifier;

    EXCEPTION
      WHEN OTHERS
      THEN
         g_error_message    := 'Error formatting national identifier' || SQLERRM;
         g_label2           := 'National Identifier:';
         g_secondary_column := l_national_identifier;

         RAISE skip_record;

    END;

    /*************************************************************************************************************
    -- PROCEDURE get_location_code
    -- Author: Ibrahim Konak
    -- Date:  Feb 26 2007
    -- Parameters:
    -- Description: This procedure provides location code lookup for location id.
    **************************************************************************************************************/
    FUNCTION get_location_code (p_location_id  IN NUMBER)
      RETURN VARCHAR2
    IS
      l_location_code  hr_locations.location_code%TYPE;

	  CURSOR c_location_code IS
	  (SELECT location_code
        FROM hr_locations
       WHERE location_id = p_location_id);

    BEGIN
      g_module_name := 'get_location_code';

      OPEN c_location_code;
	  FETCH c_location_code INTO l_location_code;
	  CLOSE c_location_code;

      RETURN l_location_code;
    EXCEPTION
      WHEN OTHERS
      THEN
         RETURN NULL;
    END;

/******************************************************************

   Procedure Create Matchpoint
    -- Author: Elango Pandu
    -- Date:  Sep 15 2009
    -- Parameters:
    -- Description: This procedure creates matchpoint special infomraiotn
    -- Modification Log
    -- Version    Developer              Date         Description
    -- ---        ----------------    -----------     --------------------------------
    -- 1.0        Elango Pandu        Sep 15 2009    Created.
    --
    -- Modification Log

    -- Version    Developer              Date         Description
    -- ---        ----------------    -----------     --------------------------------

    -- 1.10        CChan              Jan 18 2010     Hirepoint Integration Enhancements - IB07,IB08

*********************************************************************/

      PROCEDURE   create_matchpoint(
                                p_business_group_id  IN  NUMBER,
                                p_person_id          IN  NUMBER,
                                p_effective_date     IN  DATE,
                                p_segment_1          IN  VARCHAR2,
                                p_segment_2          IN  VARCHAR2,
                                p_segment_3          IN  VARCHAR2,
                                p_segment_4          IN  VARCHAR2,
                                p_segment_5          IN  VARCHAR2,
                                p_segment_6          IN  VARCHAR2,
                                p_segment_7          IN  VARCHAR2,
                                p_segment_8          IN  VARCHAR2,
                                p_segment_9          IN  VARCHAR2,
                                p_segment_10         IN  VARCHAR2,
                                p_segment_11         IN  VARCHAR2,
                                p_segment_12         IN  VARCHAR2,
                                p_segment_13         IN  VARCHAR2,
                                p_segment_14         IN  VARCHAR2,
                                p_segment_15         IN  VARCHAR2,
                                p_segment_16         IN  VARCHAR2,/* Version 1.10 */
                                p_segment_17         IN  VARCHAR2,/* Version 1.10 */
--                                p_segment_18         IN  VARCHAR2,/* Version 2.8 */
--                                p_segment_19         IN  VARCHAR2,/* Version 2.8 */
--                                p_segment_20         IN  VARCHAR2,/* Version 2.8 */
--                                p_segment_21         IN  VARCHAR2,/* Version 2.8 */
                                p_segment_22         IN  VARCHAR2, /* Version 3.0 */
                                p_segment_23         IN  VARCHAR2, /* Version 3.0 */
                                p_segment_24         IN  VARCHAR2, /* Version 3.0 */
                                p_segment_25         IN  VARCHAR2, /* Version 3.0 */
                                p_segment_26         IN  VARCHAR2, /* Version 3.0 */
                                p_segment_27         IN  VARCHAR2, /* Version 3.0 */
                                p_segment_28         IN  VARCHAR2, /* Version 3.0 */
                                p_segment_29         IN  VARCHAR2, /* Version 3.0 */
                                p_segment_30         IN  VARCHAR2  /* Version 3.0 */
                                ) IS


    v_analysis_criteria_id      per_person_analyses.analysis_criteria_id%TYPE;
    v_person_analysis_id        per_person_analyses.person_analysis_id%TYPE;
    v_pea_object_version_number per_person_analyses.object_version_number%TYPE;
    v_id_flex   fnd_id_flex_structures_vl.id_flex_num%TYPE;

    l_success_flag              g_success_flag%TYPE;
    l_error_message             g_error_message%TYPE;
    l_segment15                 per_analysis_criteria.segment15%TYPE;
    l_segment16                 per_analysis_criteria.segment16%TYPE;

    CURSOR c_id_flex IS
    SELECT id_flex_num
    FROM fnd_id_flex_structures_vl
    WHERE structure_view_name = 'MATCHPOINT_DATA';

   BEGIN
      g_module_name := 'create_matchpoint';

 Fnd_File.put_line(Fnd_File.LOG, 'l_segment15 '||l_segment15);
Fnd_File.put_line(Fnd_File.LOG, 'l_segment15 '||l_segment16);

       OPEN c_id_flex;
       FETCH c_id_flex INTO v_id_flex;
       CLOSE c_id_flex;

       l_segment15 := substr(p_segment_15,1,150);
       l_segment16 := substr(p_segment_16,1,150);

       Fnd_File.put_line(Fnd_File.LOG, 'l_segment15 '||l_segment15);
       Fnd_File.put_line(Fnd_File.LOG, 'l_segment15 '||l_segment16);

        hr_sit_api.create_sit
            (p_person_id                  =>  p_person_id,
             p_business_group_id          =>  p_business_group_id,
             p_id_flex_num                =>  v_id_flex,
             p_effective_date             =>  p_effective_date,
             p_date_from                  =>  p_effective_date,
             p_segment1                   =>  p_segment_1,
             p_segment2                   =>  p_segment_2,
             p_segment3                   =>  p_segment_3,
             p_segment4                   =>  p_segment_4,
             p_segment5                   =>  p_segment_5,
             p_segment6                   =>  p_segment_6,
             p_segment7                   =>  p_segment_7,
             p_segment8                   =>  p_segment_8,
             p_segment9                   =>  p_segment_9,
             p_segment10                  =>  p_segment_10,
             p_segment11                  =>  p_segment_11,
             p_segment12                  =>  p_segment_12,
             p_segment13                  =>  p_segment_13,
             p_segment14                  =>  p_segment_14,
             p_segment15                  =>  p_segment_15,
             p_segment16                  =>  l_segment16, /* Version 1.10 */
             p_segment17                  =>  p_segment_17, /* Version 1.10 */
--             p_segment18                  =>  p_segment_18, /* Version 2.8 */
--             p_segment19                  =>  p_segment_19, /* Version 2.8 */
--             p_segment20                  =>  p_segment_20, /* Version 2.8 */
--             p_segment21                  =>  p_segment_21, /* Version 2.8 */
             p_segment22                  =>  p_segment_22, /* Version 3.0 */
             p_segment23                  =>  p_segment_23, /* Version 3.0 */
             p_segment24                  =>  p_segment_24, /* Version 3.0 */
             p_segment25                  =>  p_segment_25, /* Version 3.0 */
             p_segment26                  =>  p_segment_26, /* Version 3.0 */
             p_segment27                  =>  p_segment_27, /* Version 3.0 */
             p_segment28                  =>  p_segment_28, /* Version 3.0 */
             p_segment29                  =>  p_segment_29, /* Version 3.0 */
             p_segment30                  =>  p_segment_30, /* Version 3.0 */
             p_analysis_criteria_id       =>  v_analysis_criteria_id,
             p_person_analysis_id         =>  v_person_analysis_id,
             p_pea_object_version_number  =>  v_pea_object_version_number);

            l_success_flag := 'Y';

    EXCEPTION
    WHEN OTHERS
    THEN
       Fnd_File.put_line(Fnd_File.LOG, 'Error at SIT: '||DBMS_UTILITY.FORMAT_ERROR_STACK );
        l_success_flag      := 'N';
        l_error_message     := SQLERRM;
        g_error_message     := 'Error others in Create Matchpoint ' || SQLERRM;
        g_label2            := 'Person Id';
        g_secondary_column  := p_person_id;
        RAISE skip_record;
   END  create_matchpoint;
/******************************************************************

   Procedure Create HireIQ
    -- Author: Christiane chan
    -- Date:  May 12 2014
    -- Parameters:
    -- Description: This procedure creates HireIQ special infomraiotn
    -- Modification Log
    -- Version    Developer              Date         Description
    -- ---        ----------------    -----------     --------------------------------
    -- 1.0        Christiane chan     May 12 2014     Initial Delivery through 3.4
    --
    -- Modification Log

    -- Version    Developer              Date         Description
    -- ---        ----------------    -----------     --------------------------------

*********************************************************************/

      PROCEDURE create_hireiq(
                                p_business_group_id  IN  NUMBER,
                                p_person_id          IN  NUMBER,
                                p_effective_date     IN  DATE,
                                p_segment_1          IN  VARCHAR2,
                                p_segment_3          IN  VARCHAR2,
                                p_segment_6          IN  VARCHAR2,
                                p_segment_9          IN  VARCHAR2,
                                p_segment_12         IN  VARCHAR2,
                                p_segment_15         IN  VARCHAR2,
                                p_segment_18         IN  VARCHAR2,
                                p_segment_21         IN  VARCHAR2
                              ) IS


    v_analysis_criteria_id      per_person_analyses.analysis_criteria_id%TYPE;
    v_person_analysis_id        per_person_analyses.person_analysis_id%TYPE;
    v_pea_object_version_number per_person_analyses.object_version_number%TYPE;
    v_id_flex   fnd_id_flex_structures_vl.id_flex_num%TYPE;

    l_success_flag              g_success_flag%TYPE;
    l_error_message             g_error_message%TYPE;
    l_segment1                  per_analysis_criteria.segment1%TYPE;
    l_segment3                  per_analysis_criteria.segment3%TYPE;
    l_segment6                  per_analysis_criteria.segment6%TYPE;
    l_segment9                  per_analysis_criteria.segment9%TYPE;
    l_segment12                 per_analysis_criteria.segment12%TYPE;
    l_segment15                 per_analysis_criteria.segment15%TYPE;
    l_segment18                 per_analysis_criteria.segment18%TYPE;
    l_segment21                 per_analysis_criteria.segment21%TYPE;

    CURSOR c_id_flex IS
    SELECT id_flex_num
    FROM fnd_id_flex_structures_vl
    WHERE structure_view_name = 'TELETECH_HIREIQ';

   BEGIN
      g_module_name := 'create_hireiq';

       OPEN c_id_flex;
       FETCH c_id_flex INTO v_id_flex;
       CLOSE c_id_flex;

        hr_sit_api.create_sit
            (p_person_id                  =>  p_person_id,
             p_business_group_id          =>  p_business_group_id,
             p_id_flex_num                =>  v_id_flex,
             p_effective_date             =>  p_effective_date,
             p_date_from                  =>  p_effective_date,
             p_segment1                   =>  p_segment_1,
             p_segment3                   =>  p_segment_3,
             p_segment6                   =>  p_segment_6,
             p_segment9                   =>  p_segment_9,
             p_segment12                  =>  p_segment_12,
             p_segment15                  =>  p_segment_15,
             p_segment18                  =>  p_segment_18,
             p_segment21                  =>  p_segment_21,
             p_analysis_criteria_id       =>  v_analysis_criteria_id,
             p_person_analysis_id         =>  v_person_analysis_id,
             p_pea_object_version_number  =>  v_pea_object_version_number);

            l_success_flag := 'Y';

    EXCEPTION
    WHEN OTHERS
    THEN
        l_success_flag      := 'N';
        l_error_message     := SQLERRM;
        g_error_message     := 'Error others in Create HireIQ ' || SQLERRM;
        g_label2            := 'Person Id';
        g_secondary_column  := p_person_id;
        RAISE skip_record;
   END  create_hireiq;

   /*************************************************************************************************************
    -- PROCEDURE create_employee
    -- Author: Ibrahim Konak
    -- Date:  Feb 26 2007
    -- Parameters:
    -- Description: This procedure creates employee record.
    -- Modification Log
    -- Version    Developer              Date         Description
    -- ---        ----------------    -----------     --------------------------------
    -- 1.0        Ibrahim Konak       Feb 26 2007     Created.
    -- 1.4        MLagostena          Jan 23 2008     Added South Africa to the Integration.
    -- 1.5        MLagostena          Jan 26 2009     Added Argentina to the Integration.
    -- 1.6.1      NMondada            Mar 30 2009     Added Mexico to the Integration.
    -- 1.6.2      MLagostena          May 26 2009     Added Race/Ethnicity Field Validation Change (US)
    -- 1.7        CChan               Jun 04 2008     Added costa Rica to the Integration.
    -- 1.9        CChan               Jan 18 2010     Added Religion Capture Method to UK
    -- 1.10        CChan              Jan 18 2010     Hirepoint Integration Enhancements - IB07,IB08
    **************************************************************************************************************/
    PROCEDURE create_employee (
      p_business_group_id           IN       NUMBER,
      p_hire_date                   IN       DATE,
      p_attribute_category          IN       VARCHAR2 DEFAULT NULL,
      p_pension_elig                IN       VARCHAR2 DEFAULT NULL,
      p_candidate_id                IN       VARCHAR2,
      p_title                                 IN       VARCHAR2, /* 7.3.1 */
      p_last_name                   IN       VARCHAR2,
      p_first_name                  IN       VARCHAR2,
      p_middle_names                IN       VARCHAR2,
      p_PREFERREDNAME               IN       VARCHAR2, /* 4.0.4 */
      p_sex                         IN       VARCHAR2,
      p_person_type_id              IN       NUMBER,
      p_nationality                 IN       VARCHAR2 DEFAULT NULL,
      p_national_identifier         IN       VARCHAR2,
      p_date_of_birth               IN       DATE,
      p_country                     IN       VARCHAR2,
      p_ethnicity                   IN       VARCHAR2,
      p_original_date_of_hire       IN       DATE,
      p_marital_status              IN       VARCHAR2,
      p_email                       IN       VARCHAR2 DEFAULT NULL,
      p_veteran                     IN       VARCHAR2 DEFAULT NULL,
      p_religion                    IN       VARCHAR2 DEFAULT NULL,
      p_legacy_emp_number           IN       VARCHAR2 DEFAULT NULL,
      /* Version 1.4 - ZA Integration */
      p_organization_id             IN       NUMBER,
      p_registered_disabled_flag    IN       VARCHAR2,
      p_user_person_type            IN       VARCHAR2,
      /* Version 1.5 - ARG Integration */
      p_socialsecurityid            IN       VARCHAR2,
      p_birthcountry                IN       VARCHAR2,
      p_sstype                      IN       VARCHAR2,
      p_education_level             IN       VARCHAR2,
      /* Version 1.6.1 - MEX Integration */
      p_region_of_birth             IN       VARCHAR2,
      p_state_of_birth              IN       VARCHAR2,
      p_maternal_last_name          IN       VARCHAR2,
      p_town_of_birth               IN       VARCHAR2,
      p_rfc_id                      IN       VARCHAR2, /* 3.5.3 */
      /* Version 1.6.2 - US Ethnic enhancement*/
      p_ethnic_disclosed            IN       VARCHAR2,
      /* Version 1.8 --  ZA Visa Expiration Date enhancement */
--      p_VisaExpirationDate          IN       DATE,
      p_VisaExpirationDate          IN       VARCHAR2, /* Version 1.10 */
      /* Version 1.9 --  Add Religion Capture Method to UK */
      p_capture_method              IN       VARCHAR2 DEFAULT NULL,
      --p_DISABILITYTYPE              IN       VARCHAR2, /* 4.0.6 */
      /* Version 5.0 - Motif India Integration */
	  P_RESIDENTSTATUS	            IN 	     VARCHAR2,
	  P_PANCARDNUMBER	            IN 	     VARCHAR2,
	  P_PANCARDNAME	                IN 	     VARCHAR2,
	  P_ADHARCARDNUMBER	            IN 	     VARCHAR2,
	  P_ADHARCARDNAME	            IN 	     VARCHAR2,
	  P_VOTERID	                    IN 	     VARCHAR2,
	  P_EPFNUMBER	                IN 	     VARCHAR2,
	  P_UANNUMBER	                IN 	     VARCHAR2,
      P_ARBITRATION_AGREEMENT       IN 	     VARCHAR2, /* 6.3 */
	  p_cpf_number                  IN       VARCHAR2, /* 6.8 */
      /*added by Rajesh*/
       p_AMKA                  IN       VARCHAR2,
       p_AMA                   IN       VARCHAR2,
       p_IDENTITIY_CARD_NUM    IN       VARCHAR2,
      /*added by Rajesh*/
       p_ee_enddate    IN       VARCHAR2,
       p_citizenship                IN       VARCHAR2,      -- Added as part of 8.1
       p_tax_number                 IN       NUMBER,        -- Added as part of 8.3
       p_FLASTNAME                 IN       VARCHAR2,        -- Added as part of 8.5
       p_MLASTNAME                 IN       VARCHAR2,        -- Added as part of 8.5
       P_AUS_TAX_STATE             IN       VARCHAR2,        -- Added as part of 8.6
	   P_AUS_JOB                   IN       VARCHAR2,        -- Added as part of 8.6
      p_employee_number             OUT      VARCHAR2,
      p_person_id                   OUT      NUMBER,
      p_assignment_number           OUT      VARCHAR2,
      p_asg_object_version_number   OUT      NUMBER,
      p_assignment_id               OUT      NUMBER,
      p_full_name                   OUT      VARCHAR2
   )
   IS

      l_per_object_version_number   per_all_people_f.object_version_number%TYPE;
      l_per_effective_start_date    per_all_people_f.effective_start_date%TYPE;
      l_per_effective_end_date      per_all_people_f.effective_end_date%TYPE;
      l_full_name                   per_all_people_f.full_name%TYPE;
      l_first_name                  per_all_people_f.first_name%TYPE;    /* 6.5 */
      l_last_name                   per_all_people_f.last_name%TYPE;     /* 6.5 */
      l_middle_names                per_all_people_f.middle_names%TYPE;  /* 6.5 */
      l_known_as                    per_all_people_f.known_as %TYPE; /* 4.0.4 */
      l_per_comment_id              per_all_people_f.comment_id%TYPE;
      l_assignment_sequence         per_all_assignments_f.assignment_sequence%TYPE;
	  l_national_identifier         per_all_people_f.national_identifier%TYPE; /*6.8*/
      l_name_combination_warning    BOOLEAN;
      l_assign_payroll_warning      BOOLEAN;
      l_orig_hire_warning           BOOLEAN;

      l_employee_number             per_all_people_f.employee_number%TYPE;
      l_person_id                   per_all_people_f.person_id%TYPE;
      l_assignment_id               per_all_assignments_f.assignment_id%TYPE;
      l_attribute_category          per_all_people_f.attribute_category%TYPE;
      l_pension_elig                per_all_people_f.attribute3%TYPE;
      l_attribute6                  per_all_people_f.attribute6%TYPE; --MODIFIED l_religion to be only the attr6 as it is used for different fields according to the country
      l_legacy_emp_number           per_all_people_f.attribute12%TYPE;
      l_candidate_id                per_all_people_f.attribute30%TYPE;
      l_veteran                     per_all_people_f.per_information5%TYPE;
      l_per_information1            per_all_people_f.per_information1%TYPE;
      l_marital_status              per_all_people_f.marital_status%TYPE;

      l_information_category        per_all_people_f.per_information_category%TYPE;

      /* Version 1.4 - ZA Integration */
      l_nationality                 per_all_people_f.nationality%TYPE;
      l_registered_disabled_flag    per_all_people_f.registered_disabled_flag%TYPE;
      l_person_type_id              per_all_people_f.person_type_id%TYPE;
      /* Version 1.5 - ARG Integration */
      l_attribute7                  per_all_people_f.attribute7%TYPE;
       /*added by Rajesh*/
      l_attribute8                  per_all_people_f.attribute8%TYPE;
      l_attribute9                  per_all_people_f.attribute9%TYPE;
      /*added by Rajesh*/
      l_birthcountry                per_all_people_f.country_of_birth%TYPE;
      l_education_level             per_all_people_f.attribute5%TYPE;
      l_religion                    per_all_people_f.attribute6%TYPE;
      /* Version 1.6.1 - MEX integration */
      l_region_of_birth             per_all_people_f.region_of_birth%TYPE;
      l_town_of_birth               per_all_people_f.town_of_birth%TYPE;
      l_per_information3            per_all_people_f.per_information3%TYPE;

      /* Version 5.0 - Motif India Integration */
      l_per_information7		    per_all_people_f.per_information7%TYPE;   -- /* 5.0 */ RESIDENTSTATUS
      l_per_information4		    per_all_people_f.per_information4%TYPE;   -- /* 5.0 */ PANCARDNUMBER
      l_per_information16		    per_all_people_f.per_information16%TYPE;  -- /* 5.0 */ ADHARCARDNUMBER
--      l_per_information18		    per_all_people_f.per_information18%TYPE;  -- /* 5.0 */ PANCARDNAME      /* 6.1 */
--      l_per_information19		    per_all_people_f.per_information19%TYPE;  -- /* 5.0 */ ADHARCARDNAME    /* 6.1 */
--      l_per_information20		    per_all_people_f.per_information20%TYPE;  -- /* 5.0 */ VOTERID          /* 6.1 */
      l_ATTRIBUTE26		            per_all_people_f.ATTRIBUTE26%TYPE;  -- /* 5.0 */ PANCARDNAME      /* 6.1 */
      l_ATTRIBUTE27		            per_all_people_f.ATTRIBUTE27%TYPE;  -- /* 5.0 */ ADHARCARDNAME    /* 6.1 */
      l_ATTRIBUTE28		            per_all_people_f.ATTRIBUTE28%TYPE;  -- /* 5.0 */ VOTERID          /* 6.1 */
      l_per_information8		    per_all_people_f.per_information8%TYPE;   -- /* 5.0 */ EPFNUMBER
      l_per_information17		    per_all_people_f.per_information17%TYPE;  -- /* 5.0 */ UANNUMBER

      l_per_information2            per_all_people_f.per_information2%TYPE;  /* 3.5.3 */
      l_adjusted_svc_date           date:= NULL; /* 3.5.5 */
      /* Version 1.6.2 - US Ethnic Enhanment */
      l_per_information11           per_all_people_f.per_information11%TYPE;
       /* End of Version 1.6.2 */
      /* Version 1.8 - ZA Visa Expiration Date enhancement */
      /* Version 1.10  replacing attribute2 to attribute13 for Global requirement on Visa Expiration Date
      l_attribute2                  per_all_people_f.attribute2%TYPE;
      */
       /* Version 1.9 --  Add Religion Capture Method to UK */
      l_attribute10                 per_all_people_f.attribute10%TYPE;
       /* Version 1.10--  Global Visa Expiration Date enhancement */
      l_attribute13                 per_all_people_f.attribute13%TYPE;
      --l_attribute29                 per_all_people_f.attribute29%TYPE;/* 4.0.6 */
      l_ATTRIBUTE20		            per_all_people_f.ATTRIBUTE20%TYPE; /* 6.3 */
      l_title		                       per_all_people_f.title%TYPE; /* 7.3.1 */




   BEGIN
      g_module_name := 'create_employee';

      l_candidate_id            := p_candidate_id;
      l_information_category    := p_country;
      l_marital_status          := p_marital_status;
      l_education_level         := NULL;
      l_attribute6              := NULL;
      l_attribute_category      := NULL;
      l_region_of_birth         := NULL;
      l_attribute7              := NULL;
      l_town_of_birth           := NULL;
      l_per_information1        := NULL;

      /* 5.0 Motif India Integration */
	  l_per_information4		:=	NULL;
	  l_per_information7		:=	NULL;
	  l_per_information8		:=	NULL;
	  l_per_information16		:=	NULL;
	  l_per_information17		:=	NULL;
--	  l_per_information18		:=	NULL; /* 6.1 */
--	  l_per_information19		:=	NULL; /* 6.1 */
--	  l_per_information20		:=	NULL; /* 6.1 */
	  l_ATTRIBUTE26		        :=	NULL; /* 6.1 */
	  l_ATTRIBUTE27		        :=	NULL; /* 6.1 */
	  l_ATTRIBUTE28		        :=	NULL; /* 6.1 */

      l_per_information3		:=	NULL; -- Added by CC during 5.0. It should be intitialized to NULL and was missing

      l_per_information11       := NULL;
      l_birthcountry            := NULL; /* Version 1.7 */
    --  l_attribute2              := NULL; /* Version 1.8 */ /* Commented out for Version 1.10 */
      l_attribute10             := NULL; /* Version 1.9 */
      l_attribute13             := p_VisaExpirationDate; /* Version 1.10 */
      l_per_information2        := NULL; /* 3.5.3 */
      l_known_as                := NULL; /* 4.0.4 */
      --l_attribute29             := NULL; /* 4.0.6 */
	  l_ATTRIBUTE20		        :=	NULL; /* 6.3 */

      l_last_name      := INITCAP(p_last_name); /* 6.5 */
      l_first_name     := INITCAP(p_first_name);/* 6.5 */
      l_middle_names   := INITCAP(p_middle_names); /* 6.5 */
      l_known_as     := INITCAP(l_known_as); /* 4.0.4 */
	  l_national_identifier     :=  p_national_identifier; /* 6.8 */
      l_title := NULL; /* 7.3.1 */

   l_attribute8             := NULL;
     l_attribute9             := NULL;
      /* 7.3 Begin  */
      IF p_business_group_id = 54749
      THEN
          l_title := p_title; /* 7.3.1 */
          l_attribute8:=p_AMKA;
          l_attribute9  :=p_AMA;
          l_attribute6:=l_national_identifier;
          l_attribute_category    :=  p_business_group_id;--NULL;
          l_attribute7 := p_IDENTITIY_CARD_NUM;
       --   l_information_category  :=  NULL;

           fnd_file.put_line(fnd_file.log, 'l_attribute8	                =>'|| l_attribute8);
           fnd_file.put_line(fnd_file.log, 'l_attribute9	                =>'|| l_attribute9);
           fnd_file.put_line(fnd_file.log, 'l_attribute7	                =>'|| l_attribute7);
       END IF;
       /* 7.3 End  */



      IF p_business_group_id = 1517     -- PHL
      THEN
         l_attribute_category   := p_business_group_id;
         l_information_category := NULL;

         l_registered_disabled_flag := p_registered_disabled_flag;  -- Added as part of 8.2

      END IF;

	  IF p_business_group_id = 1839     -- AU                            --Begin-8.6
      THEN
         l_per_information2     := P_AUS_TAX_STATE;     --Aus State Tax
         l_attribute_category   := p_business_group_id;
         l_information_category := NULL;
		 l_attribute6           := P_AUS_JOB;            --AUS Job
      END IF;                                                            --End-8.6

      IF p_business_group_id = 326   --CA
      THEN
         l_pension_elig     := p_pension_elig;
         l_marital_status   := NULL;
         l_attribute10      := TO_CHAR(to_date(p_ee_enddate,'DD-MON-YY'),'YYYY/MM/DD HH:MI:SS');
         l_attribute_category   := p_business_group_id;
      ELSE
         l_pension_elig     := NULL;
      END IF;

      IF p_business_group_id = 1631 THEN

        l_birthcountry      := p_birthcountry ;
        l_town_of_birth     := p_town_of_birth; /* 4.0.1 */
        --l_education_level   := p_education_level; /* 4.0.3 */ move to CLL_F038_PERSON_DATA.EDUCATION_LEVEL
        l_known_as          := SUBSTR(p_preferredname,1,80); /* 4.0.4 */
        l_per_information1 :=  p_ethnicity; /* 4.0.5 */ --do not default ro any value unless we instructed
        --l_attribute29       := p_disabilitytype; /* 4.0.6 */

        l_last_name      := UPPER(p_last_name); /* 6.5 */
        l_first_name     := UPPER(p_first_name);/* 6.5 */
        l_middle_names   := UPPER(p_middle_names); /* 6.5 */
        l_known_as       := UPPER(l_known_as); /* 6.5 */
		l_national_identifier := p_cpf_number; /*6.8*/
        l_region_of_birth      := p_region_of_birth;/*6.8*/

      END IF ;

      IF p_business_group_id = 325
      THEN              -- US
         l_veteran      := p_veteran;  --US only
         l_per_information1 := p_ethnicity;
         l_per_information11 := p_ethnic_disclosed;
         l_attribute_category   := p_business_group_id;
         l_registered_disabled_flag := p_registered_disabled_flag;  -- Added as part of 8.0

         /* 6.3  Begin */
         IF TRIM(P_ARBITRATION_AGREEMENT) = '//' THEN
            l_ATTRIBUTE20 := NULL;
         ELSE
            l_ATTRIBUTE20 := SUBSTR(TRIM(P_ARBITRATION_AGREEMENT),1,150);
         END IF;
         /* 6.3  End */
      ELSIF p_business_group_id = 1517 THEN           -- Added as part of 8.1
        l_ATTRIBUTE20 := p_citizenship;            -- Added as part of 8.1
      ELSE
         l_veteran      := NULL;
         l_ATTRIBUTE20 := NULL; /* 6.3 */
      END IF;

      IF p_business_group_id = 1761  --UK
      THEN
         l_attribute6           := p_religion;  --UK only
         l_legacy_emp_number    := p_legacy_emp_number;  --UK only
         l_marital_status       := NULL;
         l_attribute_category   := p_business_group_id;
         l_attribute10          := p_capture_method;  /* Version 1.9 */
      ELSE
         l_legacy_emp_number    := NULL;
      END IF;


       if apps.ttec_get_bg (p_business_group_id, p_organization_id) = 67246 /*8.5 Colombia*/
       then
       l_per_information3:= p_MLASTNAME;
       l_per_information4:= p_FLASTNAME;

       end if;

      IF apps.ttec_get_bg (p_business_group_id, p_organization_id) = 6536 /* Version 1.3 - ZA Integration */
      THEN
         l_information_category     := 'CR';
         l_per_information1         := p_ethnicity; -- Added as part of 8.4
         l_per_information2         := p_tax_number;    -- Added as part of 8.4
       --l_nationality              := NULL;            --8.8
		 l_nationality              := p_nationality;   --8.8
         l_registered_disabled_flag := p_registered_disabled_flag;
         l_person_type_id           := p_user_person_type;
       --  l_attribute_category       := p_business_group_id; /* Version 1.8 */ /* Commented out for Version 1.10 */
       --  l_attribute2               := p_VisaExpirationDate; /* Version 1.8 */ /* Commented out for Version 1.10 */

      ELSE
         l_nationality              := p_nationality;
         -- l_registered_disabled_flag := NULL; -- Commented for 8.0
         l_person_type_id           := p_person_type_id;

      END IF;


      IF p_business_group_id = 1632  /* Version 1.4 - ARG Integration */
      THEN
         l_attribute_category   := p_business_group_id;
         l_attribute7           := p_socialsecurityid;
         l_birthcountry         := p_birthcountry;
         l_attribute6           := p_sstype;
         l_education_level      := p_education_level;
      END IF;


      IF p_business_group_id = 1633  /* Version 1.6.1 - MEX Integration */
      THEN
         l_attribute_category   := p_business_group_id;
         l_region_of_birth      := p_region_of_birth;
         l_per_information3     := p_socialsecurityid;
         l_attribute7           := p_state_of_birth;
         l_per_information1     := p_maternal_last_name;
         l_town_of_birth        := p_town_of_birth;
         l_education_level      := p_education_level;
         l_birthcountry         := p_birthcountry;
         l_nationality          := p_nationality;  /* 3.5.1 */
         l_per_information2     := p_rfc_id;       /* 3.5.3 */
         l_adjusted_svc_date    := p_hire_date; /* 3.5.5 */

      END IF;

      IF p_business_group_id = 48558  /* Version 5.0 - Motif India Integration */
      THEN
            l_attribute_category    :=  p_business_group_id;
            l_information_category  :=  NULL;
	        l_per_information4		:=	P_PANCARDNUMBER;
	        l_per_information7		:=	P_RESIDENTSTATUS;
	        l_per_information8		:=	P_EPFNUMBER;
	        l_per_information16		:=	P_ADHARCARDNUMBER;
	        l_per_information17		:=	P_UANNUMBER;
--	        l_per_information18		:=	P_PANCARDNAME;  /* 6.1 */
--	        l_per_information19		:=	P_ADHARCARDNAME;/* 6.1 */
--	        l_per_information20		:=	P_VOTERID;      /* 6.1 */
	        l_ATTRIBUTE26		:=	P_PANCARDNAME;  /* 6.1 */
	        l_ATTRIBUTE27		:=	P_ADHARCARDNAME;/* 6.1 */
	        l_ATTRIBUTE28		:=	P_VOTERID;      /* 6.1 */

      END IF;

      IF apps.ttec_get_bg (p_business_group_id, p_organization_id) = 5075 /* Version 1.7 - CR Integration */
         OR ( p_business_group_id = 5054 and apps.ttec_get_bg (p_business_group_id, p_organization_id) != 6536 ) /* 7.0 */
      THEN
         l_attribute_category   := p_business_group_id;
         l_information_category := 'CR';
         l_birthcountry         := p_birthcountry;
         l_education_level      := p_education_level;
         l_attribute_category := NULL;
      END IF;


      fnd_file.put_line(fnd_file.log, 'p_hire_date                      =>'|| p_hire_date);
      fnd_file.put_line(fnd_file.log, 'p_business_group_id              =>'|| p_business_group_id);
      fnd_file.put_line(fnd_file.log, 'p_title                                  =>'|| l_title );    /* 7.3.1 */
      fnd_file.put_line(fnd_file.log, 'p_last_name                      =>'|| l_last_name);    /* 6.5 */
      fnd_file.put_line(fnd_file.log, 'p_first_name                     =>'|| l_first_name);   /* 6.5 */
      fnd_file.put_line(fnd_file.log, 'p_middle_names                   =>'|| l_middle_names); /* 6.5 */
      fnd_file.put_line(fnd_file.log, 'p_known_as                       =>'|| l_known_as); /* 4.0.4 */ /* 6.5 */
      fnd_file.put_line(fnd_file.log, 'p_sex                            =>'|| p_sex);
      fnd_file.put_line(fnd_file.log, 'p_person_type_id                 =>'|| l_person_type_id);
      fnd_file.put_line(fnd_file.log, 'p_date_of_birth                  =>'|| p_date_of_birth);
      fnd_file.put_line(fnd_file.log, 'p_nationality                    =>'|| l_nationality); --p_nationality, change for ZA integration      fnd_file.put_line(fnd_file.log, 'p_per_information_category       =>'|| l_information_category);
      fnd_file.put_line(fnd_file.log, 'p_per_information1               =>'|| l_per_information1);
      fnd_file.put_line(fnd_file.log, 'p_per_information5               =>'|| l_veteran);---new
      fnd_file.put_line(fnd_file.log, 'p_original_date_of_hire          =>'|| p_original_date_of_hire);
      fnd_file.put_line(fnd_file.log, 'p_marital_status                 =>'|| l_marital_status);
	  fnd_file.put_line(fnd_file.log, 'p_national_identifier            =>'|| l_national_identifier); /* 6.8 */
      fnd_file.put_line(fnd_file.log, 'p_attribute_category             =>'|| l_attribute_category);
      fnd_file.put_line(fnd_file.log, 'p_attribute1                     =>'|| p_email);--new p_email_address  ??????
      fnd_file.put_line(fnd_file.log, 'p_attribute13                    =>'|| l_attribute13);--p_religion
      fnd_file.put_line(fnd_file.log, 'p_attribute10                    =>'|| l_attribute10); --p_capture_method /*version 1.9 */
      fnd_file.put_line(fnd_file.log, 'p_attribute12                    =>'|| l_legacy_emp_number);
      fnd_file.put_line(fnd_file.log, 'p_attribute30                    =>'|| l_candidate_id);
      fnd_file.put_line(fnd_file.log, 'p_registered_disabled_flag       =>'|| l_registered_disabled_flag);
      fnd_file.put_line(fnd_file.log, 'p_attribute5                     =>'|| l_education_level);
      fnd_file.put_line(fnd_file.log, 'p_attribute7                     =>'|| l_attribute7); -- social security id for ARG / State of Birth for MEX
      fnd_file.put_line(fnd_file.log, 'p_country_of_birth               =>'|| l_birthcountry);
      fnd_file.put_line(fnd_file.log, 'p_region_of_birth                =>'|| l_region_of_birth);
      fnd_file.put_line(fnd_file.log, 'p_per_information3               =>'|| l_per_information3); -- social security id for MEX
      fnd_file.put_line(fnd_file.log, 'p_town_of_birth                  =>'|| l_town_of_birth);
      fnd_file.put_line(fnd_file.log, 'p_per_information2               =>'|| l_per_information2); -- RFC id for MEX /* 3.5.3 */
      fnd_file.put_line(fnd_file.log, 'p_adjusted_svc_date              =>'|| l_adjusted_svc_date); /* 3.5.5 */
      fnd_file.put_line(fnd_file.log, 'p_per_information11              =>'|| l_per_information11);
      fnd_file.put_line(fnd_file.log, '/* Version 5.0 - Motif India Integration */');
      fnd_file.put_line(fnd_file.log, 'p_per_information4	            =>'|| l_per_information4);	/* 5.0 */
      fnd_file.put_line(fnd_file.log, 'p_per_information7	            =>'|| l_per_information7);	/* 5.0 */
      fnd_file.put_line(fnd_file.log, 'p_per_information8	            =>'|| l_per_information8);	/* 5.0 */
      fnd_file.put_line(fnd_file.log, 'p_per_information16	            =>'|| l_per_information16);	/* 5.0 */
      fnd_file.put_line(fnd_file.log, 'p_per_information17	            =>'|| l_per_information17);	/* 5.0 */
--      fnd_file.put_line(fnd_file.log, 'p_per_information18	            =>'|| l_per_information18);	/* 5.0 */ /* 6.1 */
--      fnd_file.put_line(fnd_file.log, 'p_per_information19	            =>'|| l_per_information19);	/* 5.0 */ /* 6.1 */
--      fnd_file.put_line(fnd_file.log, 'p_per_information20	            =>'|| l_per_information20);	/* 5.0 */ /* 6.1 */
      fnd_file.put_line(fnd_file.log, 'p_ATTRIBUTE26	                =>'|| l_ATTRIBUTE26);	 /* 6.1 */
      fnd_file.put_line(fnd_file.log, 'p_ATTRIBUTE27	                =>'|| l_ATTRIBUTE27);	 /* 6.1 */
      fnd_file.put_line(fnd_file.log, 'p_ATTRIBUTE28	                =>'|| l_ATTRIBUTE28);	 /* 6.1 */
      fnd_file.put_line(fnd_file.log, 'p_ATTRIBUTE20	                =>'|| l_ATTRIBUTE20);	 /* 6.3 */
      fnd_file.put_line(fnd_file.log, 'P_AUS_TAX_STATE                  =>'|| P_AUS_TAX_STATE); /*8.6*/

      /** Create the employee in the HR Schema **/
      Hr_Employee_Api.create_employee
                (p_validate                       => FALSE,
                 p_hire_date                      => p_hire_date,
                 p_business_group_id              => p_business_group_id,
                 p_title                                 => l_title, /* 7.3.1 */
                 p_last_name                      => l_last_name,    /* 6.5 */
                 p_first_name                     => l_first_name,   /* 6.5 */
                 p_middle_names                   => l_middle_names, /* 6.5 */
                 p_known_as                       => l_known_as, /* 4.0.4 */ /* 6.5 */
                 --p_attribute29                    => l_attribute29, /* 4.0.6 */
                 p_sex                            => p_sex,
                 p_person_type_id                 => l_person_type_id,
                 p_date_of_birth                  => p_date_of_birth,
                 p_nationality                    => l_nationality, --p_nationality, change for ZA integration
                 p_national_identifier            => l_national_identifier,/* 6.8 */
                 p_per_information_category       => l_information_category,
                 p_per_information1               => l_per_information1,
                 p_per_information5               => l_veteran,---new
                 p_original_date_of_hire          => p_original_date_of_hire,
                 p_marital_status                 => l_marital_status,
                 p_attribute_category             => l_attribute_category,
                 p_attribute1                     => p_email,--new p_email_address  ??????
                 --p_attribute2                     => l_attribute2,--/* Version 1.8 */ /* Commented out for Version 1.10 */
                 p_attribute13                    => l_attribute13,--/* Version 1.10 */
                 --p_attribute3                     => l_pension_elig,
                 p_attribute6                     => l_attribute6, --p_religion
                 p_attribute8                     => l_attribute8, --p_AMKA for greece
                 p_attribute9                     => l_attribute9, --p_AMA  for greece
                 p_attribute10                    => l_attribute10, --p_capture_method /*version 1.9 */
                 p_attribute12                    => l_legacy_emp_number,
                 p_attribute30                    => l_candidate_id,
                 /* Version 1.4 - ZA Integration */
                 p_registered_disabled_flag       => l_registered_disabled_flag,
                 /* Version 1.6.1 - ARG Integration */
                 p_attribute5                     => l_education_level,
                 p_attribute7                     => l_attribute7, -- social security id for ARG / State of Birth for MEX
                 p_country_of_birth               => l_birthcountry,
                 /* Version 1.6.1 - MEX Integration */
                 p_region_of_birth                => l_region_of_birth,
                 p_per_information3               => l_per_information3, -- social security id for MEX
                 p_town_of_birth                  => l_town_of_birth,
                 p_per_information2               => l_per_information2, -- RFC id for MEX /* 3.5.3 */
                 p_adjusted_svc_date              => l_adjusted_svc_date, /* 3.5.5 */
                 /* Version 1.6.2 - US Ethnic enhancement*/
                 p_per_information11              => l_per_information11,
                 /* Version 5.0 - Motif India Integration */
                 p_per_information4	              => l_per_information4,	/* 5.0 */
                 p_per_information7	              => l_per_information7,	/* 5.0 */
                 p_per_information8	              => l_per_information8,	/* 5.0 */
                 p_per_information16	          => l_per_information16,	/* 5.0 */
                 p_per_information17	          => l_per_information17,	/* 5.0 */
--                 p_per_information18	          => l_per_information18,	/* 5.0 */ /* 6.1 */
--                 p_per_information19	          => l_per_information19,	/* 5.0 */ /* 6.1 */
--                 p_per_information20	          => l_per_information20,	/* 5.0 */ /* 6.1 */
                 p_ATTRIBUTE26	                  => l_ATTRIBUTE26, /* 6.1 */
                 p_ATTRIBUTE27	                  => l_ATTRIBUTE27, /* 6.1 */
                 p_ATTRIBUTE28	                  => l_ATTRIBUTE28, /* 6.1 */
                 p_ATTRIBUTE20	                  => l_ATTRIBUTE20, /* 6.3 */
                 --OUT Parameters
                 p_employee_number                => p_employee_number,
                 p_person_id                      => p_person_id,
                 p_assignment_id                  => p_assignment_id,
                 p_per_object_version_number      => l_per_object_version_number,
                 p_asg_object_version_number      => p_asg_object_version_number,
                 p_per_effective_start_date       => l_per_effective_start_date,
                 p_per_effective_end_date         => l_per_effective_end_date,
                 p_full_name                      => p_full_name,
                 p_per_comment_id                 => l_per_comment_id,
                 p_assignment_sequence            => l_assignment_sequence,
                 p_assignment_number              => p_assignment_number,
                 p_name_combination_warning       => l_name_combination_warning,
                 p_assign_payroll_warning         => l_assign_payroll_warning,
                 p_orig_hire_warning              => l_orig_hire_warning
                );
   EXCEPTION
      WHEN OTHERS
      THEN
         g_error_message    := 'Error employee creation' || SQLERRM;
         g_label2           := 'Candidate';
         g_secondary_column := p_candidate_id;
         RAISE skip_record;
   END;

   /*************************************************************************************************************
   -- PROCEDURE create_cwk
   -- Author: Ibrahim Konak
   -- Date:  Feb 26 2007
   -- Parameters:
   -- Description: This procedure creates contingent worker record.
   **************************************************************************************************************/
   PROCEDURE create_cwk(
      p_business_group_id           IN       NUMBER,
      p_hire_date                   IN       DATE,
      p_candidate_id                IN       VARCHAR2,
      p_person_type_id              IN       NUMBER,
      p_last_name                   IN       VARCHAR2,
      p_first_name                  IN       VARCHAR2,
      p_middle_names                IN       VARCHAR2,
      p_sex                         IN       VARCHAR2,
      p_nationality                 IN       VARCHAR2 DEFAULT NULL,
      p_national_identifier         IN       VARCHAR2,
      p_date_of_birth               IN       DATE,
      p_country                     IN       VARCHAR2,
      p_original_date_of_hire       IN       DATE,
      p_marital_status              IN       VARCHAR2,
      p_email                       IN       VARCHAR2 DEFAULT NULL,
      p_npw_number                  OUT      VARCHAR2,
      p_person_id                   OUT      NUMBER,
      p_assignment_number           OUT      VARCHAR2,
      p_asg_object_version_number   OUT      NUMBER,
      p_assignment_id               OUT      NUMBER,
      p_full_name                   OUT      VARCHAR2
   )
IS

    v_object_version_number       per_all_people_f.object_version_number%TYPE;
    v_effective_start_date        per_all_people_f.effective_start_date%TYPE;
    v_effective_end_date          per_all_people_f.effective_end_date%TYPE;
    v_pdp_object_version_number   per_all_assignments_f.object_version_number%TYPE;
    v_comment_id                  NUMBER;
    v_assignment_sequence         per_all_assignments_f.assignment_sequence%TYPE;
    v_name_combination_warning    BOOLEAN;


    CURSOR c_person_type
    IS
     (SELECT person_type_id
        FROM per_person_types
       WHERE system_person_type = 'CWK'
         AND user_person_type = 'Employee'
         AND business_group_id = p_business_group_id);

BEGIN
    g_module_name := 'create_cwk';

    hr_contingent_worker_api.create_cwk(
        p_start_date                    =>  p_hire_date,
        p_business_group_id             =>  p_business_group_id,
        p_last_name                     => INITCAP(p_last_name),
        p_first_name                    => INITCAP(p_first_name),
        p_middle_names                  => INITCAP(p_middle_names),
        p_person_type_id                => p_person_type_id,
        p_sex                           => p_sex,
        p_date_of_birth                 => p_date_of_birth,
        p_nationality                   => p_nationality,
        p_national_identifier           => p_national_identifier,
        p_per_information_category      => p_country,
        p_marital_status                => p_marital_status,
        p_attribute_category            => p_business_group_id,
        p_attribute1                    => p_email,
        p_attribute30                   => p_candidate_id,
        p_original_date_of_hire         => p_original_date_of_hire,
        --OUT Parameters
        p_npw_number                    => p_npw_number,
        p_person_id                     => p_person_id,
        p_per_object_version_number     => v_object_version_number,
        p_per_effective_start_date      => v_effective_start_date,
        p_per_effective_end_date        => v_effective_end_date,
        p_pdp_object_version_number     => v_pdp_object_version_number,
        p_full_name                     => p_full_name,
        p_comment_id                    => v_comment_id,
        p_assignment_id                 => p_assignment_id,
        p_asg_object_version_number     => p_asg_object_version_number,
        p_assignment_sequence           => v_assignment_sequence,
        p_assignment_number             => p_assignment_number,
        p_name_combination_warning      => v_name_combination_warning);

EXCEPTION
  WHEN OTHERS
  THEN
     g_error_message    := 'Error CWK creation' || SQLERRM;
     g_label2           := 'Candidate';
     g_secondary_column := p_candidate_id;
     RAISE skip_record;
END create_cwk;

   /*************************************************************************************************************
   -- PROCEDURE upd_cwk_assignment
   -- Author: Ibrahim Konak
   -- Date:  Feb 26 2007
   -- Parameters:
   -- Description: This procedure updates Contingnent worker assignment record.
   **************************************************************************************************************/
   PROCEDURE upd_cwk_assignment(p_candidate_id             IN      NUMBER,
                                p_effective_date        IN      DATE,
                                p_assignment_id         IN      NUMBER,
                                p_datetrack_mode        IN      VARCHAR2,
                                p_business_group_id     IN      NUMBER,
                                p_supervisor_id         IN      NUMBER,
                                p_employee_category     IN      VARCHAR2 ,
                                p_default_code_comb_id  IN      NUMBER,
                                p_set_of_books_id       IN      NUMBER,
                                p_organization_id       IN      NUMBER,
                                p_location_id           IN      NUMBER,
                                p_job_id                IN      NUMBER,
                                p_object_version_number IN OUT  NUMBER)
AS

    v_org_now_no_manager_warning      BOOLEAN;
    v_effective_start_date            DATE;
    v_effective_end_date              DATE;
    v_comment_id                      NUMBER;
    v_no_managers_warning             BOOLEAN;
    v_other_manager_warning           BOOLEAN;
    v_soft_coding_keyflex_id          NUMBER;
    v_concatenated_segments           VARCHAR2(50);
    v_hourly_salaried_warning         BOOLEAN;
    v_object_version_number           per_all_assignments_f.object_version_number%TYPE;
    v_people_group_name               VARCHAR2(150);
    v_people_group_id                 per_all_assignments_f.people_group_id%TYPE;
    v_spp_delete_warning              BOOLEAN;
    v_entries_changed_warning         VARCHAR2(50);
    v_tax_district_changed_warning    BOOLEAN;

    l_success_flag        g_success_flag%TYPE;
    l_error_message       g_error_message%TYPE;

BEGIN
    g_module_name           := 'Update CWK Assignment';
    v_object_version_number := p_object_version_number;

    BEGIN
        HR_ASSIGNMENT_API.update_cwk_asg
            (p_effective_date                  => p_effective_date,
             p_datetrack_update_mode           => p_datetrack_mode,
             p_assignment_id                   => p_assignment_id,
             p_assignment_category             => p_employee_category,
             p_default_code_comb_id            => p_default_code_comb_id,
             p_set_of_books_id                 => p_set_of_books_id,
             p_attribute_category              => p_business_group_id,
             p_object_version_number           => v_object_version_number,
             p_supervisor_id                   => p_supervisor_id,
             --OUT Parameters
             p_org_now_no_manager_warning      => v_org_now_no_manager_warning,
             p_effective_start_date            => v_effective_start_date,
             p_effective_end_date              => v_effective_end_date ,
             p_comment_id                      => v_comment_id,
             p_no_managers_warning             => v_no_managers_warning,
             p_other_manager_warning           => v_other_manager_warning,
             p_soft_coding_keyflex_id          => v_soft_coding_keyflex_id ,
             p_concatenated_segments           => v_concatenated_segments ,
             p_hourly_salaried_warning         => v_hourly_salaried_warning );

             l_success_flag := 'Y';

    EXCEPTION
        WHEN OTHERS
        THEN
            l_success_flag  := 'N';
            l_error_message := SQLERRM;

            g_error_message    := 'Error other cwk first assignment update' || SQLERRM;
            g_label2           := 'Location';
            g_secondary_column := g_location_name;

            RAISE skip_record;
    END;

    IF l_success_flag = 'Y'
    THEN

        BEGIN
            HR_ASSIGNMENT_API.update_cwk_asg_criteria
                (p_effective_date                  => p_effective_date,
                 p_datetrack_update_mode           => p_datetrack_mode,
                 p_assignment_id                   => p_assignment_id,
                 p_object_version_number           => v_object_version_number,
                 p_organization_id                 => p_organization_id,
                 p_location_id                     => p_location_id,
                 p_job_id                          => p_job_id,
                 --OUT Parameters
                 p_people_group_name               => v_people_group_name,
                 p_effective_start_date            => v_effective_start_date,
                 p_effective_end_date              => v_effective_end_date,
                 p_people_group_id                 => v_people_group_id,
                 p_org_now_no_manager_warning      => v_org_now_no_manager_warning,
                 p_other_manager_warning           => v_other_manager_warning,
                 p_spp_delete_warning              => v_spp_delete_warning,
                 p_entries_changed_warning         => v_entries_changed_warning,
                 p_tax_district_changed_warning    => v_tax_district_changed_warning);

        EXCEPTION
            WHEN OTHERS
            THEN
                 l_success_flag     := 'N';
                 l_error_message    := SQLERRM;
                 g_error_message    := 'Error other cwk second assignment update' || SQLERRM;
                 g_label2           := 'Location';
                 g_secondary_column := g_location_name;
                 RAISE skip_record;
        END;
    END IF;

    IF l_success_flag <> 'N'
    THEN
        p_object_version_number := v_object_version_number;
    END IF;

END upd_cwk_assignment;

   /*************************************************************************************************************
    -- PROCEDURE create_rate_value
    -- Author: Ibrahim Konak
    -- Date:  Feb 26 2007
    -- Parameters:
    -- Description: This procedure creates rate value for CWK.
    **************************************************************************************************************/
    PROCEDURE create_rate_value (
        p_business_group_id IN NUMBER,
        p_effective_date    IN DATE,
        p_assignment_id     IN NUMBER,
        p_rate_id           IN NUMBER,
        p_salary            IN NUMBER)
IS

    v_effective_end_date    DATE;
    v_effective_start_date  DATE;
    v_object_version_number NUMBER;
    v_grade_rule_id         NUMBER;
    l_success_flag          g_success_flag%TYPE;
    l_error_message         g_error_message%TYPE;

BEGIN
    g_module_name := 'Create Rate Value';

    hr_rate_values_api.create_assignment_rate_value
            (p_effective_date           => p_effective_date,
             p_business_group_id        => p_business_group_id,
             p_rate_id                  => p_rate_id,
             p_assignment_id            => p_assignment_id ,
             p_rate_type                => 'A',
             p_value                    => p_salary,
             p_grade_rule_id            => v_grade_rule_id,
             p_object_version_number    => v_object_version_number,
             p_effective_start_date     => v_effective_start_date,
             p_effective_end_date       => v_effective_end_date);

    l_success_flag := 'Y';

EXCEPTION
    WHEN OTHERS
    THEN
        l_success_flag      := 'N';
        l_error_message     := SQLERRM;
        g_error_message     := 'Error other CWK Create rate value ' || SQLERRM;
        g_label2            := 'Assignment Id';
        g_secondary_column  := p_assignment_id;
        RAISE skip_record;

END create_rate_value;

    /*************************************************************************************************************
    -- PROCEDURE create_agency_name
    -- Author: Ibrahim Konak
    -- Date:  Feb 26 2007
    -- Parameters:
    -- Description: This procedure creates the agency name for CWK in Special Information.
    **************************************************************************************************************/
    PROCEDURE create_agency_name (
        p_person_id         IN NUMBER,
        p_business_group_id IN NUMBER,
        p_effective_date    IN DATE,
        p_agency_name       IN VARCHAR2,
        p_ssn               IN VARCHAR2)
IS

    v_analysis_criteria_id      per_person_analyses.analysis_criteria_id%TYPE;
    v_pea_object_version_number per_person_analyses.object_version_number%TYPE;
    v_person_analysis_id        per_person_analyses.person_analysis_id%TYPE;
    v_segment1                  per_analysis_criteria.segment1%TYPE;
    l_success_flag              g_success_flag%TYPE;
    l_error_message             g_error_message%TYPE;

BEGIN
    g_module_name   := 'Create Agency Name';
    v_segment1      :=  NULL;

    IF p_ssn IS NOT NULL
    THEN
        v_segment1 := SUBSTR(p_ssn,-4);

    END IF;

    hr_sit_api.create_sit
        (p_person_id                 =>  p_person_id ,
         p_business_group_id         =>  p_business_group_id,
         p_id_flex_num               =>  50359,
         p_effective_date            =>  p_effective_date,
         p_date_from                 =>  p_effective_date,
         p_segment1                  =>  v_segment1,
         p_segment2                  =>  p_agency_name,
         p_segment3                  =>  'Y',
         p_analysis_criteria_id      =>  v_analysis_criteria_id,
         p_person_analysis_id        =>  v_person_analysis_id,
         p_pea_object_version_number =>  v_pea_object_version_number);

    l_success_flag := 'Y';

EXCEPTION
    WHEN OTHERS
    THEN
        l_success_flag      := 'N';
        l_error_message     := SQLERRM;
        g_error_message     := 'Error others in CWK Create agency name ' || SQLERRM;
        g_label2            := 'Agency Name';
        g_secondary_column  := p_agency_name;
        RAISE skip_record;

END create_agency_name;


    /*************************************************************************************************************
    -- PROCEDURE update_employee
    -- Author: Ibrahim Konak
    -- Date:  Feb 26 2007
    -- Parameters:
    -- Description: This procedure updates the employee record.
    -- Modification Log

    -- Version    Developer              Date         Description
    -- ---        ----------------    -----------     --------------------------------
    -- 1.4        MLagostena          Jan 23 2008     Added South Africa to the Integration.
    -- 1.5        MLagostena          Jan 26 2009     Added Argentina to the Integration.
    -- 1.6.1      NMondada            Mar 30 2009     Added Mexico to the Integration.
    -- 1.6.2      MLagostena          May 26 2009     Added Race/Ethnicity Field Validation Change (US)
    -- 1.6.5      MLagostena          Jun 18 2009     Added Candidate ID to procedure update_employee when the employee record is being checked for changes during re-hire. (WO#584809)
    -- 1.7        CChan               Jun 04 2008     Added costa Rica to the Integration.
    -- 1.9        CChan               Jan 18 2010     Added Religion Capture Method to UK
    -- 1.10        CChan              Jan 18 2010     Hirepoint Integration Enhancements - IB07,IB08
    **************************************************************************************************************/
    PROCEDURE update_employee (
          p_person_id                   IN   NUMBER,
          p_business_group_id           IN   NUMBER,
          p_hire_date                   IN   DATE,
          p_pension_elig                IN   VARCHAR2   DEFAULT NULL, --not used
          p_candidate_id                IN   VARCHAR2,
          p_title                              IN   VARCHAR2,          /* 7.3.1 */
          p_last_name                   IN   VARCHAR2,
          p_first_name                  IN   VARCHAR2,
          p_middle_names                IN   VARCHAR2,
          p_PREFERREDNAME               IN   VARCHAR2, /* 4.0.4 */
          p_sex                         IN   VARCHAR2,
          p_person_type_id              IN   NUMBER,
          p_date_of_birth               IN   DATE,
          p_country                     IN   VARCHAR2,
          p_ethnicity                   IN   VARCHAR2,
          p_marital_status              IN   VARCHAR2,
          p_veteran                     IN   VARCHAR2,
          p_email                       IN   VARCHAR2,
          p_nationality                 IN   VARCHAR2,
          p_religion                    IN   VARCHAR2,
          /* Version 1.4 - ZA Integration */
          p_organization_id             IN   NUMBER     DEFAULT NULL,
          p_registered_disabled_flag    IN   VARCHAR2   DEFAULT NULL,
          /* Version 1.5 - ARG Integration*/
          p_education_level             IN   VARCHAR2   DEFAULT NULL,
          /* Version 1.6.2 - US Ethnic enhancement*/
          p_ethnic_disclosed            IN   VARCHAR2,
          /* Version 1.7 - CR Integration*/
          p_birthcountry                IN   VARCHAR2,
          /* Version 1.8 --  ZA Visa Expiration Date enhancement */
--      p_VisaExpirationDate          IN       DATE,
          p_VisaExpirationDate          IN       VARCHAR2, /* Version 1.10 */
         /* Version 1.9 --  Add Religion Capture Method to UK */
          p_capture_method              IN   VARCHAR2 DEFAULT NULL,
         /* 2.1 Begin */
          p_region_of_birth             IN   VARCHAR2,
          p_state_of_birth              IN   VARCHAR2,
          p_maternal_last_name          IN   VARCHAR2,
          p_town_of_birth               IN   VARCHAR2,
         /* 2.1 End */
         /* 2.2 Begin */
          p_socialsecurityid            IN   VARCHAR2,
          p_sstype                      IN   VARCHAR2,
          p_rfc_id                      IN   VARCHAR2, /* 3.5.3 */
          --p_DISABILITYTYPE              IN   VARCHAR2, /* 4.0.6 */
         /* 2.2 End */
         /* Version 5.0 - Motif India Integration */
	      P_RESIDENTSTATUS	            IN 	     VARCHAR2,
	      P_PANCARDNUMBER	            IN 	     VARCHAR2,
	      P_PANCARDNAME	                IN 	     VARCHAR2,
	      P_ADHARCARDNUMBER	            IN 	     VARCHAR2,
	      P_ADHARCARDNAME	            IN 	     VARCHAR2,
	      P_VOTERID	                    IN 	     VARCHAR2,
	      P_EPFNUMBER	                IN 	     VARCHAR2,
	      P_UANNUMBER	                IN 	     VARCHAR2,
          P_ARBITRATION_AGREEMENT       IN       VARCHAR2, /* 6.3 */
		  P_cpf_number                  IN       VARCHAR2, /* 6.8 */
          p_AMKA                  IN       VARCHAR2,
          p_AMA                   IN       VARCHAR2,
          p_IDENTITIY_CARD_NUM    IN       VARCHAR2,
          p_ee_enddate    IN       VARCHAR2,
          p_citizenship                 IN       VARCHAR2,  -- Added as part of 8.1
          p_tax_number                  IN       NUMBER,
          p_FLASTNAME                 IN       VARCHAR2,        -- Added as part of 8.5
          p_MLASTNAME                 IN       VARCHAR2,        -- Added as part of 8.5
		  P_AUS_TAX_STATE             IN       VARCHAR2,        -- Added as part of 8.6
	      P_AUS_JOB                   IN       VARCHAR2,        -- Added as part of 8.6
          -- OUT PARAMETERS
          p_full_name                   OUT  VARCHAR2
       )
    IS
        l_employee_number             per_all_people_f.employee_number%TYPE;
        l_person_id                   per_all_people_f.person_id%TYPE;
        l_assignment_number           per_all_assignments_f.assignment_number%TYPE;
        l_assignment_id               per_all_assignments_f.assignment_id%TYPE;
        l_success_flag                g_success_flag%TYPE;

        l_error_message               g_error_message%TYPE;
        l_attribute_category          per_all_people_f.attribute_category%TYPE;
        l_pension_elig                per_all_people_f.attribute3%TYPE;
        l_change                      VARCHAR2 (1);

        l_veteran                     per_all_people_f.per_information5%TYPE;
        l_per_information1            per_all_people_f.per_information1%TYPE;
        l_nationality                 per_all_people_f.nationality%TYPE;
        l_religion                    per_all_people_f.attribute1%TYPE;
        l_marital_status              per_all_people_f.marital_status%TYPE;
        l_information_category        per_all_people_f.per_information_category%TYPE;

        l_per_object_version_number   per_all_people_f.object_version_number%TYPE;
        l_per_effective_start_date    per_all_people_f.effective_start_date%TYPE;
        l_per_effective_end_date      per_all_people_f.effective_end_date%TYPE;
        l_full_name                   per_all_people_f.full_name%TYPE;
        l_known_as                    per_all_people_f.known_as %TYPE; /* 4.0.4 */
        l_per_comment_id              per_all_people_f.comment_id%TYPE;
        l_name_combination_warning    BOOLEAN;
        l_assign_payroll_warning      BOOLEAN;
        l_orig_hire_warning           BOOLEAN;

        /* Version 1.4 - ZA Integration */
        l_registered_disabled_flag    per_all_people_f.registered_disabled_flag%TYPE;

        /* Version 1.5 - ARG Integration */
        l_education_level             per_all_people_f.attribute5%TYPE;

        /* Version 1.6.2 - US Ethnic Enhanment */
        l_per_information11           per_all_people_f.per_information11%TYPE;

        /* Version 1.7 - CR Integration */
        l_birthcountry                per_all_people_f.country_of_birth%TYPE;
        /* Version 1.8 - ZA Visa Expiration Date enhancement */
        --l_attribute2                  per_all_people_f.attribute2%TYPE; /*Commented out for Version 1.10 */
        /* Version 1.9 --  Add Religion Capture Method to UK */
        l_attribute10                 per_all_people_f.attribute10%TYPE;
        /* Version 1.10 --  Global Visa Expiration Date enhancement */
        l_attribute13                 per_all_people_f.attribute13%TYPE;
        /* Version 2.1 Begin */
        l_attribute7                  per_all_people_f.attribute7%TYPE;
        l_birthtown                   per_all_people_f.town_of_birth%TYPE;
        l_birthregion                 per_all_people_f.region_of_birth%TYPE;
         /*added by Rajesh*/
      l_attribute8                  per_all_people_f.attribute8%TYPE;
      l_attribute9                  per_all_people_f.attribute9%TYPE;
      /*added by Rajesh*/
        /* Version 2.1 End */
        l_per_information2           per_all_people_f.per_information2%TYPE; /* 3.5.3 */
        l_adjusted_svc_date          date:= null; /* 3.5.5 */
        /* Version 2.3 Begin */
        l_attribute6                  per_all_people_f.attribute6%TYPE;
        --l_attribute29                 per_all_people_f.attribute29%TYPE; /* 4.0.6 */
       l_per_information3		    per_all_people_f.per_information3%TYPE;
        /* Version 5.0 - Motif India Integration */
        l_per_information7		    per_all_people_f.per_information7%TYPE;   -- /* 5.0 */ RESIDENTSTATUS
        l_per_information4		    per_all_people_f.per_information4%TYPE;   -- /* 5.0 */ PANCARDNUMBER
        l_per_information16		    per_all_people_f.per_information16%TYPE;  -- /* 5.0 */ ADHARCARDNUMBER
--        l_per_information18		    per_all_people_f.per_information18%TYPE;  -- /* 5.0 */ PANCARDNAME  /* 6.1 */
--        l_per_information19		    per_all_people_f.per_information19%TYPE;  -- /* 5.0 */ ADHARCARDNAME /* 6.1 */
--        l_per_information20		    per_all_people_f.per_information20%TYPE;  -- /* 5.0 */ VOTERID      /* 6.1 */
        l_ATTRIBUTE26		        per_all_people_f.ATTRIBUTE26%TYPE;  -- /* 5.0 */ PANCARDNAME  /* 6.1 */
        l_ATTRIBUTE27		        per_all_people_f.ATTRIBUTE27%TYPE;  -- /* 5.0 */ ADHARCARDNAME /* 6.1 */
        l_ATTRIBUTE28		        per_all_people_f.ATTRIBUTE28%TYPE;  -- /* 5.0 */ VOTERID      /* 6.1 */
        l_per_information8		    per_all_people_f.per_information8%TYPE;   -- /* 5.0 */ EPFNUMBER
        l_per_information17		    per_all_people_f.per_information17%TYPE;  -- /* 5.0 */ UANNUMBER

        l_ATTRIBUTE20		        per_all_people_f.ATTRIBUTE20%TYPE;  -- /* 6.3 */

        l_ATTRIBUTE15		        per_all_people_f.ATTRIBUTE15%TYPE;  -- /* 6.4 */
        l_ATTRIBUTE25		        per_all_people_f.ATTRIBUTE25%TYPE;  -- /* 6.4 */
        l_ATTRIBUTE29		        per_all_people_f.ATTRIBUTE29%TYPE;  -- /* 6.4 */

        l_first_name                  per_all_people_f.first_name%TYPE;    /* 6.5 */
        l_last_name                   per_all_people_f.last_name%TYPE;     /* 6.5 */
        l_middle_names                per_all_people_f.middle_names%TYPE;  /* 6.5 */
		l_national_identifier         per_all_people_f.national_identifier%TYPE;  /* 6.8 */
        l_title                                   per_all_people_f.title%TYPE;    /* 7.3.1 */

        CURSOR c_pre_person
        IS
            SELECT *
             -- FROM hr.per_all_people_f ppf			-- Commented code by IXPRAVEEN-ARGANO,14-july-2023
              FROM APPS.per_all_people_f ppf            --  code Added by IXPRAVEEN-ARGANO,   14-july-2023
             WHERE person_id = p_person_id
               AND p_hire_date BETWEEN ppf.effective_start_date
                                    AND ppf.effective_end_date;

        r_pre_person                  c_pre_person%ROWTYPE;

    BEGIN
        g_module_name := 'update_employee';

        l_full_name                   := p_full_name;
        l_known_as                    := NULL; /* 4.0.4 */
        l_marital_status              := p_marital_status;
        l_nationality                 := NULL;
        l_information_category        := p_country;
        l_attribute_category          := NULL;
        l_education_level             := NULL;
        l_per_information1            := NULL;
        l_per_information3            := NULL; --8.5
        l_veteran                     := NULL;
        l_registered_disabled_flag    := NULL;
        l_religion                    := NULL;
        l_per_information11           := NULL;
        l_birthcountry                := NULL; /* Version 1.7 */
        --l_attribute2                  := NULL; /* Version 1.8 */ /* Commented out for Version 1.10 */
        l_attribute10                 := NULL; /* Version 1.9 */
        l_attribute13                 := p_VisaExpirationDate; /* Version 1.10 */
        /* Version 2.1 Begin */
        l_attribute7                  := NULL;
        l_per_information1            := NULL;
        l_birthtown                   := NULL;
        l_birthregion                 := NULL;
        /* Version 2.1 End */
        /* Version 2.3 Begin */
        l_attribute6                  := NULL;
        --l_attribute29                 := NULL; /* 4.0.6 */
         l_attribute8             := NULL;
         l_attribute9             := NULL;

      /* 5.0 Motif India Integration */
	    l_per_information4		:=	NULL;
	    l_per_information7		:=	NULL;
	    l_per_information8		:=	NULL;
	    l_per_information16		:=	NULL;
	    l_per_information17		:=	NULL;
--	    l_per_information18		:=	NULL; /* 6. 1 */
--	    l_per_information19		:=	NULL; /* 6. 1 */
--	    l_per_information20		:=	NULL; /* 6. 1 */
	    l_ATTRIBUTE26		    :=	NULL; /* 6. 1 */
	    l_ATTRIBUTE27		    :=	NULL; /* 6. 1 */
	    l_ATTRIBUTE28		    :=	NULL; /* 6. 1 */

        l_ATTRIBUTE20		    :=	NULL; /* 6. 3 */

        l_ATTRIBUTE15		    :=	NULL; /* 6.4 */
        l_ATTRIBUTE25		    :=	NULL; /* 6.4 */
        l_ATTRIBUTE29		    :=	NULL; /* 6.4 */

        l_first_name            :=	Initcap(p_first_name);  /* 6.5 */
        l_last_name             :=	Initcap(p_last_name);  /* 6.5 */
        l_middle_names          :=	Initcap(p_middle_names);  /* 6.5 */
        l_title            :=	NULL;  /* 7.3.1 */
        l_per_information2      := NULL;        -- Added as part of 8.4

        IF p_business_group_id = 54749 -- Greece integration
        THEN
              l_title            :=	p_title;  /* 7.3.1 */
        END IF;

    if apps.ttec_get_bg (p_business_group_id, p_organization_id) = 67246 /*8.5 Colombia*/
       then
       l_per_information3:= p_MLASTNAME;
       l_per_information4:= p_FLASTNAME;

       end if;

        IF p_business_group_id = 1517     -- PHL
        THEN
            l_information_category := NULL;
            l_ATTRIBUTE20          := p_citizenship;                -- Added as part of 8.1
            l_attribute_category   := p_business_group_id;
            l_registered_disabled_flag := p_registered_disabled_flag;  -- Added as part of 8.2

	    ELSIF p_business_group_id = 1839     -- AU                         --Begin-8.6
        THEN
         l_per_information2     := P_AUS_TAX_STATE;     --Aus State Tax
         l_attribute_category   := p_business_group_id;
         l_information_category := NULL;
		 l_attribute6           := P_AUS_JOB;            --AUS Job        --End-8.6

        --ELSIF p_business_group_id IN (326, 1761)    --CA UK
        ELSIF p_business_group_id IN (326)    --CA UK
        THEN
            l_marital_status := NULL;
            l_attribute_category    :=  p_business_group_id;
            l_attribute10      := TO_CHAR(to_date(p_ee_enddate,'DD-MON-YY'),'YYYY/MM/DD HH:MI:SS');
            l_attribute_category   := p_business_group_id;

        ELSIF p_business_group_id = 1761  -- UK
        THEN
            l_nationality  := p_nationality;
          --  l_religion     := p_religion; /* Commented out for 2.3 */
            l_attribute6   := p_religion; /* 2.3 */
            l_marital_status := NULL;
            l_attribute_category  := p_business_group_id; /* Version 1.9 */
            l_attribute10         := p_capture_method;    /* Version 1.9 */

        ELSIF p_business_group_id = 325   -- US
        THEN
            l_veteran          := p_veteran;  --US only
            l_per_information1 := p_ethnicity;
            l_per_information11:= p_ethnic_disclosed;
            l_attribute_category   := p_business_group_id;
			l_registered_disabled_flag := p_registered_disabled_flag; -- Added for 8.0

            /* 6.3  Begin */
            IF TRIM(P_ARBITRATION_AGREEMENT) = '//' THEN
               l_ATTRIBUTE20 := NULL;
            ELSE
               l_ATTRIBUTE20 := SUBSTR(TRIM(P_ARBITRATION_AGREEMENT),1,140);
            END IF;
             /* 6.3  End */

        ELSIF apps.ttec_get_bg (p_business_group_id, p_organization_id) = 6536 /* Version 1.3 - ZA Integration */
        THEN
            --l_per_information1         := NULL;       -- Commented as part of 8.4
            l_per_information1         := p_ethnicity;  -- Added as part of 8.4
            l_per_information2         := p_tax_number; -- Added as part of 8.4
            l_information_category     := 'CR';
          --l_nationality              := NULL;             --8.8
		    l_nationality              := p_nationality;    --8.8
            l_registered_disabled_flag := p_registered_disabled_flag;
            --l_attribute_category       := p_business_group_id; /* Version 1.8 */ /*Commented out for Version 1.10 */
            --l_attribute2               := p_VisaExpirationDate; /* Version 1.8 */ /*Commented out for Version 1.10 */

        ELSIF p_business_group_id = 1632  /* Version 1.5 - ARG Integration */
        THEN
            l_education_level := p_education_level;
            /* 2.3  Begin */
            l_attribute7      := p_socialsecurityid;
            l_birthcountry    := p_birthcountry;
            l_attribute6      := p_sstype;
            /* 2.3  End */
        ELSIF p_business_group_id = 1631 THEN
              l_attribute_category    :=  p_business_group_id;
              l_birthcountry    :=   p_birthcountry ; /* 4.0.1  add only here. it was missing*/
              l_birthtown       := p_town_of_birth; /* 4.0.1 */
              --l_education_level := p_education_level; /* 4.0.3 */
              l_known_as        := SUBSTR(p_preferredname,1,80); /* 4.0.4 */
              l_per_information1 := p_ethnicity;  /* 4.0.5 */ -- Do not default to any value here unless we are instructed
              --l_attribute29     := p_disabilitytype; /* 4.0.6 */
              l_last_name      := UPPER(p_last_name); /* 6.5 */
              l_first_name     := UPPER(p_first_name);/* 6.5 */
              l_middle_names   := UPPER(p_middle_names); /* 6.5 */
              l_known_as       := UPPER(l_known_as); /* 6.5 */
			  l_national_identifier    := p_cpf_number; /* 6.8 */
              l_birthregion     := p_region_of_birth;/* 6.8 */


        ELSIF p_business_group_id = 1633  /* Version 1.6.1 - MEX Integration */
        THEN
            l_attribute_category    :=  p_business_group_id;
            l_education_level := p_education_level;
            /* 2.1  begin */
            l_birthregion     := p_region_of_birth;
            l_attribute7      := p_state_of_birth;
            l_birthcountry    := p_birthcountry;
            l_per_information1:= p_maternal_last_name;
            l_birthtown       := p_town_of_birth;
            /* 2.1  end */
            l_per_information2     := p_rfc_id;       /* 3.5.3 */
            l_adjusted_svc_date    := p_hire_date; /* 3.5.5 */
        ELSIF p_business_group_id = 48558  /* Version 5.0 - Motif India Integration */
        THEN
            l_attribute_category    :=  p_business_group_id;
            l_information_category  :=  NULL;
	        l_per_information4		:=	P_PANCARDNUMBER;
	        l_per_information7		:=	P_RESIDENTSTATUS;
	        l_per_information8		:=	P_EPFNUMBER;
	        l_per_information16		:=	P_ADHARCARDNUMBER;
	        l_per_information17		:=	P_UANNUMBER;
--	        l_per_information18		:=	P_PANCARDNAME; /* 6.1 */
--	        l_per_information19		:=	P_ADHARCARDNAME;/* 6.1 */
--	        l_per_information20		:=	P_VOTERID;/* 6.1 */
	        l_ATTRIBUTE26		    :=	P_PANCARDNAME; /* 6.1 */
	        l_ATTRIBUTE27		    :=	P_ADHARCARDNAME;/* 6.1 */
	        l_ATTRIBUTE28		    :=	P_VOTERID;/* 6.1 */
        ELSIF apps.ttec_get_bg (p_business_group_id, p_organization_id) = 5075 /* Version 1.7 - CR Integration */
        THEN
            l_birthcountry     := p_birthcountry;
            l_education_level  := p_education_level;
		/* added by as part of 7.7 */
        ELSIF p_business_group_id = 5054
        THEN
            l_information_category := 'CR';
		END IF;


        OPEN c_pre_person;

        FETCH c_pre_person
         INTO r_pre_person;

        CLOSE c_pre_person;

        l_change                      := 'N';
        l_per_object_version_number   := r_pre_person.object_version_number;
        l_employee_number             := r_pre_person.employee_number;
        l_national_identifier         := r_pre_person.national_identifier; /* 7.1 */

        /* 7.1 Begin */
        IF p_business_group_id = 1631 THEN

             IF r_pre_person.NATIONAL_IDENTIFIER <> p_cpf_number /* 7.1 */

             THEN
                 l_change := 'Y';
			     l_national_identifier := p_cpf_number; /* 6.8 */ /* 7.1 re-assign the change value for BRZ */

             END IF;
        END IF;
        /* 7.1 End */

        /* 7.3.1 Begin */
        IF p_business_group_id =  54749  THEN

             IF r_pre_person.title<> p_title /* 7.3.1 */
             THEN
                 l_change := 'Y';
			     l_title := p_title; /* 7.3.1 */
             END IF;

          l_attribute8:=  p_AMKA;
          l_attribute9  := p_AMA;
          l_attribute6:=l_national_identifier;
          l_attribute_category := p_business_group_id;--NULL;
          l_attribute7:=  p_IDENTITIY_CARD_NUM;

        END IF;
        /* 7.3.1 End */

        IF p_last_name IS NOT NULL
        THEN

            IF    r_pre_person.last_name <> l_last_name /* 6.5  modified from p_last_name to l_last_name */
                OR r_pre_person.last_name IS NULL
            THEN
                l_change := 'Y';

            END IF;

        END IF;

        IF p_first_name IS NOT NULL
        THEN

            IF    r_pre_person.first_name <> l_first_name /* 6.5  modified from p_first_name to l_first_name */
                OR r_pre_person.first_name IS NULL
            THEN
                l_change := 'Y';

            END IF;

        END IF;

        IF p_middle_names IS NOT NULL
        THEN

            IF    r_pre_person.middle_names <> l_middle_names /* 6.5  modified from p_middle_names to l_middle_names */
                OR r_pre_person.middle_names IS NULL
            THEN
                l_change := 'Y';

            END IF;

        END IF;


        IF p_date_of_birth IS NOT NULL
        THEN

            IF    r_pre_person.date_of_birth <> p_date_of_birth
                OR r_pre_person.date_of_birth IS NULL
            THEN
                l_change := 'Y';

            END IF;

        END IF;

        IF p_sex IS NOT NULL
        THEN

            IF r_pre_person.sex <> p_sex OR r_pre_person.sex IS NULL
            THEN
                l_change := 'Y';

            END IF;

        END IF;


        IF p_email IS NOT NULL
        THEN

            IF    r_pre_person.attribute1 <> p_email
                OR r_pre_person.attribute1 IS NULL
            THEN
                l_change := 'Y';

            END IF;

        END IF;

        IF p_candidate_id IS NOT NULL
        THEN

            IF    r_pre_person.attribute30 <> p_candidate_id
                OR r_pre_person.attribute30 IS NULL
            THEN
                l_change := 'Y';

            END IF;

        END IF;

        IF l_nationality IS NOT NULL
        THEN
            IF    r_pre_person.nationality <> l_nationality
                OR r_pre_person.nationality IS NULL
            THEN
                l_change := 'Y';

            END IF;

        END IF;

        /* Version 1.6.5 Checking Candidate ID*/
        IF p_candidate_id IS NOT NULL
        THEN

            IF    r_pre_person.attribute30 <> p_candidate_id
                OR r_pre_person.attribute30 IS NULL
            THEN
                l_change := 'Y';

            END IF;

        END IF;
        /* End Version 1.6.5*/

        /* Version 1.10 */
        IF p_VisaExpirationDate IS NOT NULL
        THEN
            IF    r_pre_person.attribute13 <> p_VisaExpirationDate
                OR r_pre_person.attribute13 IS NULL
            THEN
                l_change := 'Y';

            END IF;
        END IF;
        /* End Version 1.10*/

        /*COUNTRY SPECIFIC VALIDATIONS*/


        IF p_business_group_id IN (325, 1517, 1632)          /* Version 1.5 - ARG Integration */
            OR (apps.ttec_get_bg (p_business_group_id, p_organization_id) IN  (6536, -- /* Version 1.4 - ZA Integration */
                                                                               5075)) -- /* Version 1.7 */
        THEN

            IF p_marital_status IS NOT NULL
            THEN

                IF    r_pre_person.marital_status <> p_marital_status
                    OR r_pre_person.marital_status IS NULL
                THEN
                    l_change := 'Y';

                END IF;

            END IF;

            IF l_registered_disabled_flag IS NOT NULL
            THEN
                IF r_pre_person.registered_disabled_flag <> l_registered_disabled_flag
                  OR r_pre_person.registered_disabled_flag IS NULL
                THEN
                    l_change := 'Y' ;
                END IF;
            END IF;     -- Added as part of 8.2

        END IF; /* Version 1.5 - ARG Integration / Version 1.4 - ZA Integration */


        /* Version 1.6.2 - US Ethnic enhancement*/
        IF p_business_group_id = 325
        THEN

            /* Version 1.6.2 - US Ethnic enhancement

            /*It is require to update always the ethnicity field
            and disclosed ethnicity field, so for US there is
            always considered as a l_change = 'Y'*/


            /*IF p_veteran IS NOT NULL
            THEN
               IF    r_pre_person.per_information5 <> p_veteran
                  OR r_pre_person.per_information5 IS NULL
               THEN
                  l_change := 'Y';
               END IF;
            END IF;
            */

            l_change := 'Y';

            /*End Version 1.6.2*/
        END IF;

        /* 6.4 Begin */
        IF p_business_group_id = 326
        THEN

            IF  r_pre_person.attribute15 IS NOT NULL
            THEN
                l_attribute15 := r_pre_person.attribute15;
                l_change := 'Y';

            END IF;

            IF  r_pre_person.attribute25 IS NOT NULL
            THEN
                l_attribute25 := r_pre_person.attribute25;
                l_change := 'Y';

            END IF;

            IF  r_pre_person.attribute29 IS NOT NULL
            THEN
                l_attribute29 := r_pre_person.attribute29;
                l_change := 'Y';

            END IF;

        END IF;
        /* 6.4 End */

        IF p_business_group_id = 1761  -- UK /* Version 1.10 */
        THEN

            IF p_religion IS NOT NULL /* Version 1.10 */
            THEN

                IF    r_pre_person.attribute6 <> p_religion
                    OR r_pre_person.attribute6 IS NULL
                THEN
                    l_change := 'Y';

                END IF;

            END IF;

            IF p_capture_method IS NOT NULL /* Version 1.10 */
            THEN

                IF    r_pre_person.attribute10 <> p_capture_method
                    OR r_pre_person.attribute10 IS NULL
                THEN
                    l_change := 'Y';

                END IF;

            END IF;
        END IF;

        IF apps.ttec_get_bg (p_business_group_id, p_organization_id) = 5075 -- /* Version 1.7*/
        THEN
            IF p_birthcountry IS NOT NULL
            THEN

                IF    r_pre_person.country_of_birth <> p_birthcountry
                    OR r_pre_person.country_of_birth IS NULL
                THEN
                    l_change := 'Y';

                END IF;

            END IF;

        END IF; /* Version 1.7 -  CR Integrations */

/* Commented out for Version 1.10 */
--        IF apps.ttec_get_bg (p_business_group_id, p_organization_id) = 6536 -- /* Version 1.8*/
--        THEN
--            IF p_VisaExpirationDate IS NOT NULL
--            THEN

--                IF    r_pre_person.attribute2 <> p_VisaExpirationDate
--                    OR r_pre_person.attribute2 IS NULL
--                THEN
--                    l_change := 'Y';

--                END IF;

--            END IF;

--        END IF; */
        /* Version 1.8 -  ZA Visa Expiration Date enhancement */

        /* Version 1.9 --  Add Religion Capture Method to UK */
        IF p_business_group_id = 1761  -- UK
        THEN
            IF p_religion IS NOT NULL
            THEN

                IF    r_pre_person.attribute6 <> p_religion
                    OR r_pre_person.attribute6 IS NULL
                THEN
                    l_change := 'Y';

                END IF;

            END IF;

            IF p_capture_method IS NOT NULL
            THEN

                IF    r_pre_person.attribute10 <> p_capture_method
                    OR r_pre_person.attribute10 IS NULL
                THEN
                    l_change := 'Y';

                END IF;

            END IF;

        END IF;

        IF p_business_group_id = 1633          /* Version 2.1 Begin */
        THEN

            IF p_region_of_birth IS NOT NULL
            THEN

                IF    r_pre_person.region_of_birth <> p_region_of_birth
                    OR r_pre_person.region_of_birth IS NULL
                THEN
                    l_change := 'Y';

                END IF;
            END IF;

            IF p_education_level IS NOT NULL
            THEN

                IF    r_pre_person.attribute5 <> p_education_level
                   OR r_pre_person.attribute5 IS NULL
                THEN
                    l_change := 'Y';

                END IF;
            END IF;

            IF p_state_of_birth IS NOT NULL
            THEN

                IF    r_pre_person.attribute7 <> p_state_of_birth
                    OR r_pre_person.attribute7 IS NULL
                THEN
                    l_change := 'Y';

                END IF;
            END IF;

            IF p_birthcountry IS NOT NULL
            THEN

                IF    r_pre_person.country_of_birth <> p_birthcountry
                    OR r_pre_person.country_of_birth IS NULL
                THEN
                    l_change := 'Y';

                END IF;
            END IF;

            IF p_town_of_birth IS NOT NULL
            THEN

                IF    r_pre_person.town_of_birth <> p_town_of_birth
                    OR r_pre_person.town_of_birth IS NULL
                THEN
                    l_change := 'Y';

                END IF;
            END IF;

            IF p_maternal_last_name IS NOT NULL
            THEN

                IF    r_pre_person.per_information1 <> p_maternal_last_name
                    OR r_pre_person.per_information1 IS NULL
                THEN
                    l_change := 'Y';

                END IF;
            END IF;

        END IF; /* Version 2.1 - MEX Rehire Fix */

        IF p_business_group_id = 1632          /* Version 2.3 Begin */
        THEN

            IF p_birthcountry IS NOT NULL
            THEN

                IF    r_pre_person.country_of_birth <> p_birthcountry
                    OR r_pre_person.country_of_birth IS NULL
                THEN
                    l_change := 'Y';

                END IF;
            END IF;

            IF p_education_level IS NOT NULL
            THEN

                IF    r_pre_person.attribute5 <> p_education_level
                   OR r_pre_person.attribute5 IS NULL
                THEN
                    l_change := 'Y';

                END IF;
            END IF;

            IF p_sstype IS NOT NULL
            THEN

                IF    r_pre_person.attribute6 <> p_sstype
                    OR r_pre_person.attribute6 IS NULL
                THEN
                    l_change := 'Y';

                END IF;
            END IF;

            IF p_socialsecurityid IS NOT NULL
            THEN

                IF    r_pre_person.attribute7 <> p_socialsecurityid
                    OR r_pre_person.attribute7 IS NULL
                THEN
                    l_change := 'Y';

                END IF;
            END IF;

        END IF; /* Version 2.3 - Arg Rehire Fix */

       IF p_business_group_id = 1631          /* Version 4.0 Begin */
        THEN

            IF p_ethnicity IS NOT NULL
            THEN

                IF    r_pre_person.per_information1 <> p_ethnicity
                    OR r_pre_person.per_information1 IS NULL
                THEN
                    l_change := 'Y';

                END IF;
            END IF;

--            IF p_education_level IS NOT NULL /* 4.0.3 */
--            THEN

--                IF    r_pre_person.attribute5 <> p_education_level
--                   OR r_pre_person.attribute5 IS NULL
--                THEN
--                    l_change := 'Y';

--                END IF;
--            END IF;

            IF p_birthcountry IS NOT NULL
            THEN

                IF    r_pre_person.country_of_birth <> p_birthcountry
                    OR r_pre_person.country_of_birth IS NULL
                THEN
                    l_change := 'Y';

                END IF;
            END IF;

            IF p_town_of_birth IS NOT NULL /* 4.0.1 */
            THEN

                IF    r_pre_person.town_of_birth <> p_town_of_birth
                    OR r_pre_person.town_of_birth IS NULL
                THEN
                    l_change := 'Y';

                END IF;
            END IF;

            IF p_region_of_birth IS NOT NULL /*6.8 start*/
            THEN

                IF    r_pre_person.region_of_birth <> p_region_of_birth
                    OR r_pre_person.region_of_birth IS NULL
                THEN
                    l_change := 'Y';

                END IF;
            END IF; /*6.8 end*/

            IF p_preferredname IS NOT NULL /* 4.0.4 */
            THEN

                IF    r_pre_person.known_as <> p_preferredname
                    OR r_pre_person.known_as IS NULL
                THEN
                    l_change := 'Y';

                END IF;
            END IF;

--            IF p_disabilitytype IS NOT NULL /* 4.0.6 */
--            THEN

--                IF    r_pre_person.attribute29 <> p_disabilitytype
--                    OR r_pre_person.attribute29 IS NULL
--                THEN
--                    l_change := 'Y';

--                END IF;
--            END IF;

        END IF; /* Version 4.0 - BRZ enhancement */

       IF p_business_group_id = 48558         /* Version 5.0 - Motif India Integration  Begin*/
        THEN

            IF P_PANCARDNUMBER IS NOT NULL
            THEN

                IF    r_pre_person.per_information4 <>P_PANCARDNUMBER
                    OR r_pre_person.per_information4 IS NULL
                THEN
                    l_change := 'Y';

                END IF;
            END IF;

            IF P_RESIDENTSTATUS IS NOT NULL
            THEN

                IF    r_pre_person.per_information7<> P_RESIDENTSTATUS
                   OR r_pre_person.per_information7 IS NULL
                THEN
                    l_change := 'Y';

                END IF;
            END IF;

            IF P_EPFNUMBER IS NOT NULL
            THEN

                IF    r_pre_person.per_information8 <> P_EPFNUMBER
                    OR r_pre_person.per_information8 IS NULL
                THEN
                    l_change := 'Y';

                END IF;
            END IF;

            IF P_ADHARCARDNUMBER IS NOT NULL
            THEN

                IF    r_pre_person.per_information16 <> P_ADHARCARDNUMBER
                    OR r_pre_person.per_information16 IS NULL
                THEN
                    l_change := 'Y';

                END IF;
            END IF;

            IF P_UANNUMBER IS NOT NULL
            THEN

                IF    r_pre_person.per_information17 <> P_UANNUMBER
                    OR r_pre_person.per_information17 IS NULL
                THEN
                    l_change := 'Y';

                END IF;
            END IF;

            IF P_PANCARDNAME IS NOT NULL
            THEN

--                IF    r_pre_person.per_information18 <> P_PANCARDNAME /* 6.1 */
--                    OR r_pre_person.per_information18 IS NULL /* 6.1 */
                IF    r_pre_person.ATTRIBUTE26 <> P_PANCARDNAME /* 6.1 */
                    OR r_pre_person.ATTRIBUTE26 IS NULL /* 6.1 */
                THEN
                    l_change := 'Y';

                END IF;
            END IF;

            IF P_ADHARCARDNAME IS NOT NULL
            THEN

--                IF    r_pre_person.per_information19 <> P_ADHARCARDNAME /* 6.1 */
--                    OR r_pre_person.per_information19 IS NULL /* 6.1 */
                IF    r_pre_person.ATTRIBUTE27 <> P_ADHARCARDNAME /* 6.1 */
                    OR r_pre_person.ATTRIBUTE27 IS NULL /* 6.1 */
                THEN
                    l_change := 'Y';

                END IF;
            END IF;

            IF P_VOTERID IS NOT NULL
            THEN

--                IF    r_pre_person.per_information20 <> P_VOTERID /* 6.1 */
--                    OR r_pre_person.per_information20 IS NULL /* 6.1 */
                IF    r_pre_person.ATTRIBUTE28 <> P_VOTERID /* 6.1 */
                    OR r_pre_person.ATTRIBUTE28 IS NULL /* 6.1 */
                THEN
                    l_change := 'Y';

                END IF;
            END IF;
        END IF; /* Version 5.0 - Motif India Integration  End */


        DBMS_OUTPUT.PUT_LINE ('ObjectVN:' || r_pre_person.object_version_number);
        DBMS_OUTPUT.PUT_LINE ('Person ID:' || r_pre_person.person_id);
        DBMS_OUTPUT.PUT_LINE ('Person Start Date:'
                            || r_pre_person.effective_start_date );
        DBMS_OUTPUT.PUT_LINE ('Employee Change:' || l_change);

        fnd_file.put_line(fnd_file.log, 'l_change value                =>'|| l_change);

        IF l_change = 'N'
        THEN
            RETURN;
        END IF;



      --l_attribute_category := r_pre_person.attribute_category;

-----------------------
      fnd_file.put_line(fnd_file.log, 'Hr_Person_Api.update_person');
      fnd_file.put_line(fnd_file.log, 'p_validate                      => FALSE');
      fnd_file.put_line(fnd_file.log, 'p_effective_date                =>'|| p_hire_date);
      fnd_file.put_line(fnd_file.log, 'p_datetrack_update_mode         => CORRECTION');
      fnd_file.put_line(fnd_file.log, 'p_person_id                     =>'||  p_person_id);
      fnd_file.put_line(fnd_file.log, 'p_title                     =>'||  l_title);        /* 7.3.1 */
      fnd_file.put_line(fnd_file.log, 'p_last_name                     =>'||  l_last_name);    /* 6.5 Modified from p_last_name to l_last_name  */
      fnd_file.put_line(fnd_file.log, 'p_first_name                    =>'||  l_first_name);   /* 6.5 Modified from p_first_name to l_first_name */
      fnd_file.put_line(fnd_file.log, 'p_middle_names                  =>'||  l_middle_names); /* 6.5 Modified from p_middle_names to l_middle_names */
      fnd_file.put_line(fnd_file.log, 'p_known_as                      =>'||  l_known_as); /* 4.0.4 */ /* 6.5 */
      fnd_file.put_line(fnd_file.log, 'p_marital_status                =>'||  l_marital_status);
      fnd_file.put_line(fnd_file.log, 'p_national_identifier           =>'||  l_national_identifier); /* 6.8*/
      fnd_file.put_line(fnd_file.log, 'p_nationality                   =>'|| l_nationality);
      fnd_file.put_line(fnd_file.log, 'p_sex                           =>'||  p_sex);
      fnd_file.put_line(fnd_file.log, 'p_date_of_birth                 =>'||  p_date_of_birth);
      fnd_file.put_line(fnd_file.log, 'p_per_information_category      =>'||  l_information_category);
      fnd_file.put_line(fnd_file.log, 'p_per_information1              =>'||  l_per_information1); -- Ethnicity for ARG and BRZ/ maternal last name for MEX
      fnd_file.put_line(fnd_file.log, 'p_per_information5              =>'||  l_veteran);
      fnd_file.put_line(fnd_file.log, 'p_registered_disabled_flag      =>'||  l_registered_disabled_flag);
      fnd_file.put_line(fnd_file.log, 'p_attribute5                    =>'||  l_education_level);
      fnd_file.put_line(fnd_file.log, 'p_attribute6                    =>'||  l_attribute6);          /* 2.3 */
      fnd_file.put_line(fnd_file.log, 'p_attribute10                   =>'||  l_attribute10);       /* Version 1.9 */
      fnd_file.put_line(fnd_file.log, 'p_per_information11             =>'||  l_per_information11);
      fnd_file.put_line(fnd_file.log, 'p_attribute30                   =>'||  p_candidate_id);
      fnd_file.put_line(fnd_file.log, 'p_attribute1                    =>'||  p_email);/* Version 1.7 */
      fnd_file.put_line(fnd_file.log, 'p_attribute_category            =>'||  l_attribute_category); /* 6.3 */
      fnd_file.put_line(fnd_file.log, 'p_attribute13                   =>'||  l_attribute13);--/* Version 1.10 */
      fnd_file.put_line(fnd_file.log, 'p_attribute7                    =>'||  l_attribute7);   /* Version 2.1 */
      fnd_file.put_line(fnd_file.log, 'p_town_of_birth                 =>'||  l_birthtown);    /* Version 2.1 */
      fnd_file.put_line(fnd_file.log, 'p_region_of_birth               =>'||  l_birthregion);  /* Version 2.1 */
      fnd_file.put_line(fnd_file.log, 'p_per_information2              =>'||  l_per_information2); -- RFC id for MEX /* 3.5.3 */
      fnd_file.put_line(fnd_file.log, 'p_adjusted_svc_date             =>'||  l_adjusted_svc_date); -- for MEX /* 3.5.5 */
      fnd_file.put_line(fnd_file.log, 'p_per_information4	           =>'||  l_per_information4);	/* 5.0 */
      fnd_file.put_line(fnd_file.log, 'p_per_information7	           =>'||  l_per_information7);	/* 5.0 */
      fnd_file.put_line(fnd_file.log, 'p_per_information8	           =>'||  l_per_information8);	/* 5.0 */
      fnd_file.put_line(fnd_file.log, 'p_per_information16	           =>'||  l_per_information16);	/* 5.0 */
      fnd_file.put_line(fnd_file.log, 'p_per_information17	           =>'||  l_per_information17);	/* 5.0 */
      fnd_file.put_line(fnd_file.log, 'p_attribute20	               =>'||  l_attribute20);/* 6.3 */
      fnd_file.put_line(fnd_file.log, 'p_attribute26                   =>'||  l_attribute26);/* 6.1 */
      fnd_file.put_line(fnd_file.log, 'p_attribute27                   =>'||  l_attribute27);/* 6.1 */
      fnd_file.put_line(fnd_file.log, 'p_attribute28                   =>'||  l_attribute28);/* 6.1 */
      fnd_file.put_line(fnd_file.log, 'p_attribute15                   =>'||  l_attribute15);/* 6.4 */
      fnd_file.put_line(fnd_file.log, 'p_attribute25                   =>'||  l_attribute25);/* 6.4 */
      fnd_file.put_line(fnd_file.log, 'p_attribute29                   =>'||  l_attribute29);/* 6.4 */
      fnd_file.put_line(fnd_file.log, 'p_object_version_number         =>'||  l_per_object_version_number);
      fnd_file.put_line(fnd_file.log, 'p_employee_number               =>'||  l_employee_number);
      fnd_file.put_line(fnd_file.log, 'p_country_of_birth              =>'||  l_birthcountry);  /* Version 1.7 */
	  fnd_file.put_line(fnd_file.log, 'P_AUS_TAX_STATE                 =>'||  P_AUS_TAX_STATE); /*8.6*/

-----------------------
        DBMS_OUTPUT.PUT_LINE ('Employee Change:' || l_change);

        Hr_Person_Api.update_person
               (p_validate                      => FALSE,
                p_effective_date                => p_hire_date,
                p_datetrack_update_mode         => 'CORRECTION',
                p_person_id                     => p_person_id,
                p_title                                => l_title,    /* 7.3.1 */
                p_last_name                      => l_last_name,    /* 6.5 Modified from p_last_name to l_last_name  */
                p_first_name                     => l_first_name,   /* 6.5 Modified from p_first_name to l_first_name */
                p_middle_names                   => l_middle_names, /* 6.5 Modified from p_middle_names to l_middle_names */
                p_known_as                       => l_known_as, /* 4.0.4 */ /* 6.5 */
                --p_attribute29                   => l_attribute29, /* 4.0.6 */ move over to BRZ localization
                p_marital_status                => l_marital_status,
                p_nationality                   => l_nationality,
                --unlikely change
                p_sex                           => p_sex,
                p_date_of_birth                 => p_date_of_birth,
                p_per_information_category      => l_information_category,
				p_national_identifier            => l_national_identifier, /* 6.8 */
                p_per_information3              => l_per_information3, -- 8.5
                p_per_information1              => l_per_information1, -- Ethnicity for ARG and BRZ/ maternal last name for MEX
                p_per_information5              => l_veteran,

                /* Version 1.4 - ZA Integration */
                p_registered_disabled_flag      => l_registered_disabled_flag,

                /* Version 1.5 - ARG Integration */
                p_attribute5                    => l_education_level,
                --
                --p_attribute_category            => l_attribute_category,
                --p_attribute1                    => p_email,
                --p_attribute30                   => p_candidate_id,
                --p_attribute6                     => l_religion,
             --   p_attribute_category             => l_attribute_category,/* Version 1.9 */
             --   p_attribute6                     => l_religion,          /* Version 1.9 */
                p_attribute6                     => l_attribute6,          /* 2.3 */
                p_attribute10                    => l_attribute10,       /* Version 1.9 */
                p_attribute8                     => l_attribute8, --p_AMKA for greece
                p_attribute9                     => l_attribute9, --p_AMA  for greece
                /* Version 1.6.2 - US Ethnic enhancement */
                p_per_information11             => l_per_information11,
                /* Version 1.6.5 - Candidate ID */
                p_attribute30                   => p_candidate_id,
                /* End Version 1.6.5 */
           --     p_country_of_birth              => l_birthcountry,   /* Version 1.7 */
                p_attribute1                    => p_email, /* Version 1.7 */
                p_attribute_category            => l_attribute_category, /* 6.3 */
          --      p_attribute2                    => l_attribute2, /* Version 1.8 */
                p_attribute13                    => l_attribute13,--/* Version 1.10 */
                p_attribute7                    => l_attribute7,   /* Version 2.1 */
                p_town_of_birth                 => l_birthtown,    /* Version 2.1 */
                p_region_of_birth               => l_birthregion,  /* Version 2.1 */
                p_per_information2              => l_per_information2, -- RFC id for MEX /* 3.5.3 */
                p_adjusted_svc_date             => l_adjusted_svc_date, -- for MEX /* 3.5.5 */
                 /* Version 5.0 - Motif India Integration */
                p_per_information4	            => l_per_information4,	/* 5.0 */
                p_per_information7	            => l_per_information7,	/* 5.0 */
                p_per_information8	            => l_per_information8,	/* 5.0 */
                p_per_information16	            => l_per_information16,	/* 5.0 */
                p_per_information17	            => l_per_information17,	/* 5.0 */
--                p_per_information18	            => l_per_information18,	/* 5.0 */  /* 6.1 */
--                p_per_information19	            => l_per_information19,	/* 5.0 */  /* 6.1 */
--                p_per_information20	            => l_per_information20,	/* 5.0 */  /* 6.1 */
                p_attribute20	                => l_attribute20,/* 6.3 */
                p_attribute26                   => l_attribute26,/* 6.1 */
                p_attribute27                   => l_attribute27,/* 6.1 */
                p_attribute28                   => l_attribute28,/* 6.1 */
                p_attribute15                   => l_attribute15,/* 6.4 */
                p_attribute25                   => l_attribute25,/* 6.4 */
                p_attribute29                   => l_attribute29,/* 6.4 */
                --IN OUT Parameters
                p_object_version_number         => l_per_object_version_number,
                p_employee_number               => l_employee_number,
                p_country_of_birth              => l_birthcountry,  /* Version 1.7 */
                --OUT Parameters
                p_effective_start_date          => l_per_effective_start_date,
                p_effective_end_date            => l_per_effective_end_date,
                p_full_name                     => l_full_name,
                p_comment_id                    => l_per_comment_id,
                p_name_combination_warning      => l_name_combination_warning,
                p_assign_payroll_warning        => l_assign_payroll_warning,
                p_orig_hire_warning             => l_orig_hire_warning
               );

       p_full_name := l_full_name; -- ?????

    EXCEPTION
      WHEN OTHERS
      THEN
         g_error_message := 'Error at update employee api' || SQLERRM;
         g_label2 := 'Employee';
         g_secondary_column := l_employee_number;

         RAISE skip_record;
    END;

    /*************************************************************************************************************
    -- PROCEDURE final_process_employee
    -- Author: Ibrahim Konak
    -- Date:  Feb 26 2007
    -- Parameters:
    -- Description: This procedure updates period of service with final process date.
    **************************************************************************************************************/
    PROCEDURE final_process_employee (p_validate                IN   BOOLEAN,
                                      p_business_group_id       IN   NUMBER,
                                      p_employee_number         IN   VARCHAR2,
                                      p_period_of_service_id    IN   NUMBER,
                                      p_object_version_number   IN   NUMBER,
                                      p_final_process_date      IN   DATE)
    IS
        l_success_flag    g_success_flag%TYPE;
        l_error_message   g_error_message%TYPE;

    BEGIN


   -- FND_FILE.PUT_LINE (FND_FILE.OUTPUT, 'p_final_process_date'||p_final_process_date);
        Tt_Hrms_Api_Utility_Pkg.final_process_employee
                        (ip_validate                   => p_validate,
                         ip_period_of_service_id       => p_period_of_service_id,
                         ip_object_version_number      => p_object_version_number,
                         ip_final_process_date         => p_final_process_date,
                         op_success_flag               => l_success_flag,
                         op_error_message              => l_error_message);

        IF l_success_flag = 'N'
        THEN
            RAISE api_error;
        END IF;

    EXCEPTION
        WHEN api_error
        THEN
            g_error_message    :=
                        'Error api final process employee' || l_error_message;

            g_label2           := 'Employee Number';
            g_secondary_column := p_employee_number;
            RAISE skip_record;

      WHEN OTHERS
      THEN
            g_error_message    := 'Error other final process employee ' || SQLERRM;
            g_label2           := 'Employee Number';
            g_secondary_column := p_employee_number;
            RAISE skip_record;
    END;

    /*************************************************************************************************************
    -- PROCEDURE rehire_employee
    -- Author: Ibrahim Konak
    -- Date:  Feb 26 2007
    -- Parameters:
    -- Description: This procedure creates employee record (re-hires).
    **************************************************************************************************************/
    PROCEDURE rehire_employee (p_business_group_id              IN  NUMBER,
                                    p_hire_date                 IN  DATE,
                                    p_person_id                 IN  NUMBER,
                                    p_per_object_version_number IN  NUMBER,
                                    p_reason_code               IN  VARCHAR2,
                                    p_employee_number           IN  VARCHAR2,
                                    p_assignment_number         OUT VARCHAR2,
                                    p_asg_object_version_number OUT NUMBER,
                                    p_assignment_id             OUT NUMBER)
    IS
        l_success_flag    g_success_flag%TYPE;
        l_error_message   g_error_message%TYPE;

    BEGIN
        g_module_name := 'rehire_employee';

        Tt_Hrms_Api_Utility_Pkg.rehire
                (ip_validate                       => FALSE,
                 ip_date_start                     => p_hire_date,
                 ip_person_id                      => p_person_id,
                 ip_per_object_version_number      => p_per_object_version_number,
                 ip_reason_code                    => p_reason_code,
                 op_assignment_number              => p_assignment_number,
                 op_asg_object_version_number      => p_asg_object_version_number,
                 op_assignment_id                  => p_assignment_id,
                 op_success_flag                   => l_success_flag,
                 op_error_message                  => l_error_message
                );

        IF l_success_flag = 'N'
        THEN
            RAISE api_error;
        END IF;

    EXCEPTION
        WHEN api_error
        THEN
             g_error_message    := 'Error api rehire employee' || l_error_message;
             g_label2           := 'Employee Number';
             g_secondary_column := p_employee_number;
             RAISE skip_record;

        WHEN OTHERS
        THEN
             g_error_message    := 'Error other rehire employee ' || SQLERRM;
             g_label2           := 'Employee Number';
             g_secondary_column := p_employee_number;
             RAISE skip_record;
    END;

    /*************************************************************************************************************
    -- PROCEDURE create_stock_options
    -- Author: Ibrahim Konak
    -- Date:  Feb 26 2007
    -- Parameters:
    -- Description: This procedure adds stock options to the employee.
    **************************************************************************************************************/
    PROCEDURE create_stock_options (
                    p_business_group_id           IN       NUMBER,
                    p_hire_date                   IN       DATE,
                    p_effective_date              IN       DATE,
                    p_person_id                   IN       NUMBER,
                    p_employee_number             IN       VARCHAR2,
                    p_stock_options               IN       VARCHAR2 DEFAULT NULL
                    )
    IS

        l_analysis_criteria_id      NUMBER;
        l_person_analysis_id        NUMBER;
        l_pea_object_version_number NUMBER;
        l_stock_options             VARCHAR2(280);


   BEGIN
      g_module_name := 'add stock options';

	  l_stock_options  :=  p_stock_options;

	  IF l_stock_options IS NULL
      THEN
	     l_stock_options := 'N';

      ELSIF   l_stock_options IN ('n', 'N')
      THEN
	     l_stock_options := 'N';

      ELSE
	     l_stock_options := 'Y';

      END IF;


      Hr_Sit_Api.create_sit
           (p_validate                   => FALSE,
            p_person_id                  => p_person_id,
            p_business_group_id          => p_business_group_id,
            p_id_flex_num                =>  50214,
            p_effective_date             => p_effective_date,
            p_date_from                  => p_hire_date,
            p_segment7                   => l_stock_options,
            p_analysis_criteria_id       =>  l_analysis_criteria_id,
            p_person_analysis_id         =>   l_person_analysis_id,
            p_pea_object_version_number  => l_pea_object_version_number
            );


   EXCEPTION
      WHEN OTHERS
      THEN
         g_error_message    := 'Error create stock options api' || SQLERRM;
         g_label2           := 'Stock Option';
         g_secondary_column := p_stock_options;
         RAISE skip_record;
   END;

    /*************************************************************************************************************
    -- PROCEDURE create_stock_options
    -- Author: Ibrahim Konak
    -- Date:  Feb 26 2007
    -- Parameters:
    -- Description: This procedure updates stock options to the employee.
    **************************************************************************************************************/
   PROCEDURE update_stock_options (
      p_business_group_id           IN       NUMBER,
      p_hire_date                   IN       DATE,
	  p_effective_date              IN       DATE,
	  p_person_id                   IN       NUMBER,
      p_employee_number             IN       VARCHAR2,
      p_stock_options               IN       VARCHAR2 DEFAULT NULL
    )
    IS

        l_analysis_criteria_id      NUMBER;
        l_person_analysis_id        NUMBER;
        l_pea_object_version_number NUMBER;
        l_stock_options             VARCHAR2(280);
        l_pre_stock_options         VARCHAR2(280);
        l_change                    VARCHAR2 (1);

        CURSOR c_pre_stock
        IS
        SELECT  ac.segment7,  --required field
	            pa.person_analysis_id,
		        ac.analysis_criteria_id,
		        pa.object_version_number
		--START R12.2 Upgrade Remediation		
          /*FROM  hr.per_person_analyses pa,				-- Commented code by IXPRAVEEN-ARGANO,14-july-2023
                hr.per_analysis_criteria ac*/
		  FROM  apps.per_person_analyses pa,				 --  code Added by IXPRAVEEN-ARGANO,   14-july-2023
                apps.per_analysis_criteria ac	
		--END R12.2.12 Upgrade remediation
         WHERE pa.analysis_criteria_id = ac.analysis_criteria_id
           AND pa.id_flex_num = 50214
           AND pa.person_id = p_person_id
           AND p_hire_date BETWEEN date_from AND NVL (date_to, '31-DEC-4712');

   BEGIN
      g_module_name := 'update stock options';

	  l_stock_options := p_stock_options;

	  IF l_stock_options IS NULL
      THEN
	     l_stock_options := 'N';

      ELSIF   l_stock_options IN ('n', 'N')
      THEN
	     l_stock_options := 'N';

      ELSE
	     l_stock_options := 'Y';

      END IF;


	  OPEN c_pre_stock;

      FETCH c_pre_stock
      INTO l_pre_stock_options,
	       l_person_analysis_id,
	       l_analysis_criteria_id,
		   l_pea_object_version_number;

      CLOSE c_pre_stock;

	  IF l_pre_stock_options IS NULL
      THEN
	     create_stock_options (
           p_business_group_id  => p_business_group_id,
           p_hire_date          => p_hire_date,
	       p_effective_date     => p_hire_date,
	       p_person_id          => p_person_id,
           p_employee_number    => p_employee_number,
           p_stock_options      => p_stock_options);

	  ELSIF l_pre_stock_options <> l_stock_options
      THEN
	     Hr_Sit_Api.update_sit
          (p_validate                   => FALSE,
           p_date_from                  => p_hire_date,
		   p_segment7                   => l_stock_options,
           p_person_analysis_id         =>  l_person_analysis_id,
           p_analysis_criteria_id       =>  l_analysis_criteria_id,  --IN OUT
           p_pea_object_version_number  => l_pea_object_version_number  --IN OUT
        );

	  END IF;

   EXCEPTION
      WHEN OTHERS
      THEN
         g_error_message    := 'Error update stock options' || SQLERRM;
         g_label2           := 'Stock Option';
         g_secondary_column := p_stock_options;
         RAISE skip_record;
   END;


    /*************************************************************************************************************
    -- PROCEDURE create_address
    -- Author: Ibrahim Konak
    -- Date:  Feb 26 2007
    -- Parameters:
    -- Description: Procedure creates primary address record
    -- Modification Log
    --
    -- Version    Developer              Date         Description
    -- ---        ----------------    -----------     --------------------------------
    -- 1.2.2      NMondada            Aug 08 2008     Modified proc update_address to end date Non-primary
                                                      address for employees during the rehire process
    -- 1.3.1      NMondada            Nov 05 2008     Terminate all primary and secondary addresses without
                                                      checking for changes, and create a new primary address.
    -- 1.4        MLagostena          Jan 23 2008     Added South Africa to the Integration.
    -- 1.5        MLagostena          Jan 26 2009     Added Argentina to the Integration.
    -- 1.6.1      NMondada            Mar 30 2009     Added Mexico to the Integration.
    -- 1.6.3      MLagostena          Jun 10 2009     Added INITCAP to city field for all BGs except ARG and for county field
    -- 1.7        CChan               Jun 04 2009     Added Costa Rica to the Integration.
    -- 2.5          RRPASULA        OCT 29 2012     Using New API for US address
    **************************************************************************************************************/
   PROCEDURE create_address (
        p_business_group_id      IN       NUMBER,
        p_person_id              IN       NUMBER,
        p_effective_date         IN       DATE,
        p_style                  IN       VARCHAR2,
        p_effective_start_date   IN       DATE,
        p_address_line1          IN       VARCHAR2,
        p_address_line2          IN       VARCHAR2,
        p_city                   IN       VARCHAR2,
        p_region_1               IN       VARCHAR2,
        p_region_2               IN       VARCHAR2,
        p_postal_code            IN       VARCHAR2,
        p_country                IN       VARCHAR2,
        p_landline               IN       VARCHAR2,
        p_mobile                 IN       VARCHAR2,
        p_email                  IN       VARCHAR2,
        /* Version 1.3 - ZA Integration */
        p_organization_id        IN       NUMBER DEFAULT NULL,
        /* Version 1.4 - ARG Integration */
        p_stateprovincedes       IN       VARCHAR2 DEFAULT NULL,
		p_stateprovincecode      IN       VARCHAR2 DEFAULT NULL,        --8.6
        p_addressdistrict        IN       VARCHAR2 DEFAULT NULL,
        p_addressneighborhood    IN       VARCHAR2 DEFAULT NULL,
        p_addressmunicipality    IN       VARCHAR2 DEFAULT NULL,
        /* 5.0 Motif India Integration */
        P_LIVEINADDRSINCE         IN   DATE,
        P_CORRESPADDRESS         IN   VARCHAR2 DEFAULT NULL,
        P_CORRESPADDRESS2         IN   VARCHAR2 DEFAULT NULL,
        P_CORRESPCITY             IN   VARCHAR2 DEFAULT NULL,
        P_CORRESPSTATE             IN   VARCHAR2 DEFAULT NULL,
        P_CORRESPZIPCODE         IN   VARCHAR2 DEFAULT NULL,
        P_CORRESPCOUNTRYCODE     IN   VARCHAR2 DEFAULT NULL,
        -- OUT Parameters
        p_success_flag           OUT      VARCHAR2,
        p_error_message          OUT      VARCHAR2
    )
    IS
        l_address_id              per_addresses.address_id%TYPE;
        l_style                   per_addresses.style%TYPE;
        l_object_version_number   per_addresses.object_version_number%TYPE;

        l_address_type            per_addresses.address_type%TYPE;
        l_region_1                per_addresses.region_1%TYPE;
        l_county                   per_addresses.region_1%TYPE;
        l_region_2                per_addresses.region_2%TYPE;

        l_landline                per_addresses.telephone_number_1%TYPE;
        l_mobile                  per_addresses.telephone_number_2%TYPE;
        l_email                   per_addresses.add_information13%TYPE;

        v_city                    per_addresses.region_1%TYPE;
        v_postal_code             per_addresses.postal_code%TYPE;
        v_state                   per_addresses.region_2%TYPE;
        l_state_code          pay_us_states.state_code%TYPE;

        /* Version 1.5 - ARG Integration */
        l_add_info15              per_addresses.add_information15%TYPE;
        l_add_info16              per_addresses.add_information16%TYPE;
        l_add_info17              per_addresses.add_information17%TYPE;

        /* Version 1.6.1 - MEX Integration */
        l_address_line1           per_addresses.address_line1%TYPE;
        l_address_line2           per_addresses.address_line2%TYPE;
        l_address_line3           per_addresses.address_line3%TYPE;

        /* Version 5.0 - Motif India Integration */
        l_phone_id                per_phones.phone_id%TYPE;

        l_country                 per_addresses.country%TYPE;   --Added for v6.6 --Vaitheghi
    BEGIN
        g_module_name := 'create_address';
        v_city              := p_city;
        v_postal_code       := p_postal_code;
        l_add_info15        := NULL;
        l_add_info16        := NULL;
        l_add_info17        := NULL;
        --l_address_line1     := INITCAP(p_address_line1); --Commented for v6.6 --Vaitheghi
        --l_address_line2     := INITCAP(p_address_line2); --Commented for v6.6 --Vaitheghi
        l_style             := p_style;
        l_address_type      := 'HOME';
        l_region_1          :=  p_region_2;
        l_region_2          := NULL;
        l_landline          := NULL;
        l_mobile            := NULL;
        l_email             := NULL;
        l_county           :=  NULL;  -- version 2.5
        l_country           :=  NULL; --Added for v6.6 --Vaitheghi

         --Added for v6.6 --Vaitheghi
        IF p_business_group_id = 1631 -- BRZ
        THEN
            l_country       :=  UPPER(p_country);
            l_address_line1     := UPPER(p_address_line1);
            l_address_line2     := UPPER(p_address_line2);
        ELSE
            l_country           := p_country;
            l_address_line1     := INITCAP(p_address_line1);
            l_address_line2     := INITCAP(p_address_line2);
        END IF;
        --End for v6.6 --Vaitheghi

        IF p_business_group_id = 1517 -- PHL
        THEN
            l_style         := 'PH_GLB';
            l_address_type  := 'PHCA';
            v_city          := INITCAP(p_city); /* Version 1.6.3 */

		ELSIF p_business_group_id = 1839    --AU    --8.6-Begin
        THEN
            l_style         := 'AU_GLB';
			l_region_1      := p_stateprovincecode;
			v_city          := INITCAP(p_city);
			l_country       := UPPER(p_country);
			l_landline      := p_landline;
            l_mobile        := p_mobile;
            l_address_type  := 'TTAU_PH';        --8.6-End

        ELSIF p_business_group_id = 325 -- USA
        THEN

              BEGIN                   -- version 2.5  state
            l_region_2 := NULL;
             l_state_code := NULL;
               SELECT state_abbrev,state_code
                 INTO  l_region_2,
                           l_state_code
                 FROM  pay_us_states
                WHERE UPPER (state_abbrev) = UPPER (p_region_2);
            EXCEPTION
               WHEN OTHERS
               THEN
                  g_error_message := 'Error in getting US state:' || SQLERRM;
                  p_success_flag := 'N';
                  p_error_message := g_error_message;

                  g_label2 := 'state';
                  g_secondary_column :=  p_region_2 ;
                  RAISE skip_record;
            END;

            BEGIN                   -- version 2.5
             l_region_1 := NULL;
               SELECT distinct(county_name)
                 INTO l_region_1
                 FROM PAY_US_COUNTIES
                WHERE UPPER (COUNTY_NAME) = trim(UPPER (p_region_1));
            EXCEPTION
               WHEN OTHERS
               THEN
                  g_error_message := 'Error in getting US County:' || SQLERRM;
                  p_success_flag := 'N';
                  p_error_message := g_error_message;

                  g_label2 := 'County';
                  g_secondary_column := p_region_1 ;
                  RAISE skip_record;
            END;

             BEGIN                   -- version 2.5  city
             v_city := NULL;
               SELECT distinct(city_name)
                 INTO v_city
                 FROM pay_us_city_names
                WHERE UPPER (city_name) = trim(UPPER (p_city)) ;

            EXCEPTION
               WHEN OTHERS
               THEN
                  g_error_message := 'Error in getting US city:' || SQLERRM;
                  p_success_flag := 'N';
                  p_error_message := g_error_message;

                  g_label2 := 'city';
                  g_secondary_column := p_city ;
                  RAISE skip_record;
            END;


          -- l_region_1      := INITCAP(p_region_1); /* Version 1.6.3 */
          --  l_region_1      := l_county;  -- version 2.5
           -- l_region_2      := p_region_2;
           -- v_city          := INITCAP(p_city); /* Version 1.6.3 */

        ELSIF p_business_group_id = 326 -- CAN
        THEN
            v_city          := INITCAP(p_city);
            v_postal_code   := SUBSTR(REPLACE(UPPER(v_postal_code),' '),1,3)
                                ||' '||
                               SUBSTR(REPLACE(UPPER(v_postal_code),' '),4,3);

        ELSIF p_business_group_id = 1761
        THEN
            l_landline      := p_landline;
            l_mobile        := p_mobile;
            l_email         := p_email;
            l_region_1      := p_region_1;  --county
            l_region_2      := NULL;  --state
            l_address_type  := NULL;
            v_city          := INITCAP(p_city); /* Version 1.6.3 */

        ELSIF apps.ttec_get_bg (p_business_group_id, p_organization_id) = 6536 /* Version 1.3 - ZA Integration */
        THEN
            l_style         := 'ZA_GLB';
            l_address_type  := 'HOME';
            l_region_1      := p_region_2; --stateprovincecode
            v_city          := INITCAP(p_city); /* Version 1.6.3 */

        ELSIF p_business_group_id = 1632 /* Version 1.5 - ARG Integration */
        THEN
            l_style         := 'AR_GLB';
            l_address_type  := '1';
            v_city          := p_city;
            l_region_1      := p_stateprovincedes;      -- Provincia
            l_add_info15    := p_addressdistrict;       -- Partido
            l_add_info16    := p_addressmunicipality;   -- Localidad
            l_add_info17    := p_addressneighborhood;   -- Barrio

         ELSIF p_business_group_id = 1631 /* Version 2.6 - Brz Integration */
        THEN
            l_style         := 'BR_GLB';
            l_address_type  := '1';
            -- Modified for v6.6 --Start Vaitheghi
            v_city          := UPPER(p_city);
            l_region_2      :=  UPPER(p_region_2);       -- Provincia
            -- Modified for v6.6 --End Vaitheghi
            /* 4.0.2 Begin */
            --l_region_1      := p_region_2;
            l_region_1      := UPPER(p_addressneighborhood);   -- Bairro -> Neighborhood
            /* 4.0.2 End */

        ELSIF p_business_group_id = 1633 /* Version 1.6.1 - MEX Integration */
        THEN
            l_style         := 'MX';
            l_address_type  := 'PHCA';
            v_city          := INITCAP(p_city); /* Version 1.6.3 */
            l_region_1      := p_region_2;             -- State Code
            l_region_2      := p_addressmunicipality;  -- Municipality
            l_address_line3 := l_address_line2;        -- Street number
            l_address_line2 := p_addressneighborhood;  -- Neighborhood
            l_landline      := p_landline; /* 3.5.2 */
            l_mobile        := p_mobile;   /* 3.5.2 */

        ELSIF (apps.ttec_get_bg (p_business_group_id, p_organization_id)) = 67246 /*8.5 Colombia Address*/
        THEN
     if upper(p_country) like 'CO%'
     then
         l_style         := 'CO_GLB';
          v_city          := INITCAP(p_city);  -- City
	 l_region_2      :=  UPPER(p_region_2); --State

     else
         l_address_type  := 'HOME';
		 v_city          := INITCAP(p_city);  -- City
		 l_region_2      :=  UPPER(p_region_2); --State
		-- l_landline      := p_landline;
        -- l_mobile        := p_mobile;
     end if;
        ELSIF (apps.ttec_get_bg (p_business_group_id, p_organization_id) IN (5075,16562) /* Version 1.7 - CR Integration */ -- v2.9
              OR  ( p_business_group_id = 5054 and apps.ttec_get_bg (p_business_group_id, p_organization_id) not in (6536,67246)))

        THEN
            l_style         := 'CR_GLB';
            l_address_type  := 'HOME';
            v_city          := INITCAP(p_city); /* Version 1.6.3 */
        ELSIF p_business_group_id = 54749 /* Version 7.3.8 - GRC Integration */
        THEN
            l_style         := 'GR_GLB';
            l_address_type  := 'HOME';
            v_city          := INITCAP(p_city);
        END IF;

        DBMS_OUTPUT.PUT_LINE (   'Region1:'
                                || l_region_1
                                || '-'
                                || 'Region2:'
                                || l_region_2
                               );

       If   p_business_group_id = 325  then
        print_line ('Entered US'||TRIM(v_city)||'-'||TRIM(l_region_2)||'-'|| TRIM(l_region_1)||'-'||l_address_type||'-'|| TRIM(p_country)||'-'||TRIM(v_postal_code));

                Hr_Person_Address_Api.create_us_person_address     --2.5  US address issue.
                          (p_validate                   => FALSE,
                           p_effective_date             => trim(p_effective_date),
                           p_validate_county            => FALSE,
                           p_person_id                  =>trim( p_person_id),
                           p_primary_flag               => 'Y',
                          p_date_from                  => trim(p_effective_start_date),
                           p_address_type               => TRIM(l_address_type),
                           p_address_line1              => INITCAP(l_address_line1),
                           p_address_line2              => INITCAP(l_address_line2),
                           p_city               =>         TRIM( v_city),
                            p_state                   =>  TRIM(l_region_2),
                           p_zip_code                => TRIM(v_postal_code),
                            p_county         =>      TRIM(l_region_1),
                           p_country                    => TRIM(p_country),
                           p_telephone_number_1         => trim(l_landline),
                           p_telephone_number_2         => trim(l_mobile),
                           p_add_information13          => trim(l_email),
--                           /* Version 1.5 - ARG Integration */
--                           p_add_information15          => l_add_info15,
--                           p_add_information16          => l_add_info16,
--                           p_add_information17          => l_add_info17,
--                           /* Version 1.6.1 - MEX Integration */
--                           p_address_line3              => l_address_line3,
                           --OUT Parameters
                           p_address_id                 => l_address_id,
                           p_object_version_number      => l_object_version_number
                          );
                p_success_flag    := 'Y';
                p_error_message   := NULL;
                DBMS_OUTPUT.PUT_LINE (   'address id:'|| l_address_id );
              print_line ('address id:'|| l_address_id);


--Begin - 8.6
        ELSIF p_business_group_id = 1839  then
        --print_line ('Entered AU'||TRIM(v_city)||'-'||TRIM(l_region_2)||'-'|| TRIM(l_region_1)||'-'||l_address_type||'-'|| TRIM(p_country)||'-'||TRIM(v_postal_code));

                Hr_Person_Address_Api.create_person_address     --2.5  US address issue.
                          (p_validate                   => FALSE,
                           p_effective_date             => trim(p_effective_date),
                           p_pradd_ovlapval_override    => TRUE,
                           p_person_id                  => trim( p_person_id),
                           p_primary_flag               => 'Y',
						   p_style                      => l_style,
                           p_date_from                  => trim(p_effective_start_date),
                           p_address_type               => TRIM(l_address_type),
                           p_address_line1              => INITCAP(l_address_line1),
                           p_address_line2              => INITCAP(l_address_line2),
                           p_town_or_city               => TRIM(v_city),
                           p_region_1                   =>  TRIM(l_region_1),
                           p_postal_code                => TRIM(v_postal_code),
                           p_country                    => TRIM(l_country),
                           p_telephone_number_1         => trim(l_landline),
                           p_telephone_number_2         => trim(l_mobile),
                           --p_add_information13          => trim(l_email),
--                           /* Version 1.5 - ARG Integration */
--                           p_add_information15          => l_add_info15,
--                           p_add_information16          => l_add_info16,
--                           p_add_information17          => l_add_info17,
--                           /* Version 1.6.1 - MEX Integration */
--                           p_address_line3              => l_address_line3,
                           --OUT Parameters
                           p_address_id                 => l_address_id,
                           p_object_version_number      => l_object_version_number
                          );
                p_success_flag    := 'Y';
                p_error_message   := NULL;
                DBMS_OUTPUT.PUT_LINE (   'address id:'|| l_address_id );
                print_line ('address id:'|| l_address_id);
--End - 8.6

        ELSIF p_business_group_id = 48558 /* Version 5.0 - Motif India Integration */
        THEN
               print_line ('Create India Permanent Address');
               Hr_Person_Address_Api.create_person_address
                          (p_validate                   => FALSE,
                           p_effective_date             => trim(p_effective_date),
                           p_validate_county            => FALSE,
                           p_person_id                  => trim(p_person_id),
                           p_primary_flag               => 'Y',
                           p_style                      => 'IN',
                           p_date_from                  => trim(p_effective_date),--7.4 re-hire fix for india BG P_LIVEINADDRSINCE, --v_dtl.last_hire_date,
                           p_address_line1              => INITCAP(TRIM(p_address_line1)),
                           p_address_line2              => INITCAP(TRIM(p_address_line2)),
                           p_add_information14          => INITCAP(TRIM(p_city)),
                           p_add_information15          => TRIM(p_region_2), --'GJ',
                           p_postal_code                => TRIM(p_postal_code),
                           p_country                    => TRIM(p_country),--'IN'
                          -- p_telephone_number_1        => v_dtl.phone_number,
                           p_address_type                => 'IN_P', --Permanent',
                       --OUT Parameters
                           p_address_id                 => l_address_id,
                           p_object_version_number      => l_object_version_number);

                DBMS_OUTPUT.PUT_LINE (   'Premanent address id:'|| l_address_id );
                print_line ('Premanent address id:'|| l_address_id);

       IF P_CORRESPADDRESS IS NOT NULL THEN
                   print_line ('Create India Mailing Address');
                   Hr_Person_Address_Api.create_person_address
                              (p_validate                   => FALSE,
                               p_effective_date             => trim(p_effective_date),
                               p_validate_county            => FALSE,
                               p_person_id                  => trim(p_person_id),
                               p_primary_flag               => 'N',
                               p_style                      => 'IN',
                               p_date_from                  => p_effective_start_date, --P_LIVEINADDRSINCE, --v_dtl.last_hire_date,
                               p_address_line1              => INITCAP(TRIM(P_CORRESPADDRESS)),
                               p_address_line2              => INITCAP(TRIM(P_CORRESPADDRESS2)),
                               p_add_information14          => INITCAP(TRIM(P_CORRESPCITY)),
                               p_add_information15          => TRIM(P_CORRESPSTATE), --'GJ',
                               p_postal_code                => TRIM(P_CORRESPZIPCODE),
                               p_country                    => TRIM(P_CORRESPCOUNTRYCODE), --''IN',
                              -- p_telephone_number_1        => v_dtl.phone_number,
                               p_address_type                => 'MAILING', --Permanent',
                           --OUT Parameters
                               p_address_id                 => l_address_id,
                               p_object_version_number      => l_object_version_number);

                    DBMS_OUTPUT.PUT_LINE (   'Mailing address id:'|| l_address_id );
                    print_line ('Mailing address id:'|| l_address_id);
        END IF;

               p_success_flag    := 'Y';
               p_error_message   := NULL;

        ELSE

        FND_FILE.PUT_LINE (FND_FILE.LOG, 'Before executing general');
         print_line ('Entered General');
           Hr_Person_Address_Api.create_person_address
                      (p_validate                   => FALSE,
                       p_effective_date             => p_effective_date,
                       p_validate_county            => FALSE,
                       p_person_id                  => p_person_id,
                       p_primary_flag               => 'Y',
                       p_style                      => l_style,
                       p_date_from                  => p_effective_start_date,
                       p_address_type               => TRIM(l_address_type),
                       p_address_line1              => l_address_line1, --INITCAP(l_address_line1), --Modified for v6.6 --Vaitheghi
                       p_address_line2              => l_address_line2, --INITCAP(l_address_line2), --Modified for v6.6 --Vaitheghi
                       p_town_or_city               => TRIM(v_city),
                       p_region_1                   => TRIM(l_region_1),
                       p_region_2                   => TRIM(l_region_2),
                       p_postal_code                => TRIM(v_postal_code),
                       p_country                    => TRIM(l_country), --TRIM(p_country), --Modified for v6.6 --Vaitheghi
                       p_telephone_number_1         => l_landline,
                       p_telephone_number_2         => l_mobile,
                       p_add_information13          => l_email,
                       /* Version 1.5 - ARG Integration */
                       p_add_information15          => l_add_info15,
                       p_add_information16          => l_add_info16,
                       p_add_information17          => l_add_info17,
                       /* Version 1.6.1 - MEX Integration */
                       p_address_line3              => l_address_line3,
                       --OUT Parameters
                       p_address_id                 => l_address_id,
                       p_object_version_number      => l_object_version_number
                      );
            p_success_flag    := 'Y';
            p_error_message   := NULL;

          --  DBMS_OUTPUT.PUT_LINE (   'address id:'|| l_address_id );
      END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            g_error_message    := 'Error  address api creation:' || SQLERRM;
            p_success_flag     := 'N';
            p_error_message    := g_error_message;

            g_label2           := 'City, county, state';
            g_secondary_column := p_city || ',' || p_region_1 || ',' || p_region_2;
            RAISE skip_record;



    END;
    /*************************************************************************************************************
    -- PROCEDURE update_address
    -- Author: Ibrahim Konak
    -- Date:  Feb 26 2007
    -- Parameters:
    -- Description: This procedure updates employee address if changed.
    -- Modification Log
    --
    -- Version    Developer              Date         Description
    -- ---        ----------------    -----------     --------------------------------
    -- 1.2.2      NMondada            Aug 08 2008     Modified proc update_address to end date Non-primary
                                                      address for employees during the rehire process
    -- 1.3.1      NMondada            Nov 05 2008     Terminate all primary and secondary addresses without
                                                      checking for changes, and create a new primary address.
    -- 1.4        MLagostena          Jan 23 2008     Added South Africa to the Integration.
    -- 1.5        MLagostena          Jan 26 2009     Added Argentina to the Integration.
    -- 1.6.1      NMondada            Mar 30 2009     Added Mexico to the Integration.
    **************************************************************************************************************/
    PROCEDURE update_address (
                p_business_group_id      IN   NUMBER,
                p_person_id              IN   NUMBER,
                p_employee_number        IN   VARCHAR2,
                p_effective_date         IN   DATE,
                p_style                  IN   VARCHAR2,
                p_effective_start_date   IN   DATE,
                p_address_line1          IN   VARCHAR2,
                p_address_line2          IN   VARCHAR2,
                p_city                   IN   VARCHAR2,
                p_region_1               IN   VARCHAR2,
                p_region_2               IN   VARCHAR2,
                p_postal_code            IN   VARCHAR2,
                p_country                IN   VARCHAR2,
                p_landline               IN   VARCHAR2,
                p_mobile                 IN   VARCHAR2,
                p_email                  IN   VARCHAR2,
                /* Version 1.3 - ZA Integration */
                p_organization_id        IN   NUMBER DEFAULT NULL,
                /* Version 1.4 - ARG Integration */
                p_stateprovincedes       IN   VARCHAR2 DEFAULT NULL,
				p_stateprovincecode      IN   VARCHAR2 DEFAULT NULL,        --8.6
                p_addressdistrict        IN   VARCHAR2 DEFAULT NULL,
                p_addressneighborhood    IN   VARCHAR2 DEFAULT NULL,
                p_addressmunicipality    IN   VARCHAR2 DEFAULT NULL,
                 /* 5.0 Motif India Integration */
                P_LIVEINADDRSINCE	     IN   DATE,
	            P_CORRESPADDRESS	     IN   VARCHAR2 DEFAULT NULL,
	            P_CORRESPADDRESS2	     IN   VARCHAR2 DEFAULT NULL,
                P_CORRESPCITY            IN   VARCHAR2 DEFAULT NULL,
	            P_CORRESPSTATE           IN   VARCHAR2 DEFAULT NULL,
	            P_CORRESPZIPCODE	     IN   VARCHAR2 DEFAULT NULL,
                P_CORRESPCOUNTRYCODE     IN   VARCHAR2 DEFAULT NULL
                )
    IS
      l_success_flag    g_success_flag%TYPE;
      l_error_message   g_error_message%TYPE;
      l_change          VARCHAR2 (1);
	  v_style           VARCHAR2(100); --Added for 7.7

      /** Cursor for primary addresses **/
      CURSOR c_pre_address
      IS
         SELECT *
           FROM per_addresses
          WHERE person_id = p_person_id
            --AND address_type = 'HOME'
            AND primary_flag = 'Y'
            AND p_effective_date BETWEEN date_from AND NVL (date_to,
                                                            '31-DEC-4712');

      /*** Cursor for secondary addresses -- Version 1.3.1 ***/
      CURSOR c_pre_sec_address
      IS
         SELECT *
           FROM per_addresses
          WHERE person_id = p_person_id
            --AND address_type = 'HOME'
            AND primary_flag = 'N' -- Version 1.2.2
            AND p_effective_date BETWEEN date_from AND NVL (date_to,
                                                            '31-DEC-4712'
                                                           );

--      r_pre_address     c_pre_address%ROWTYPE; -- Version 1.2.2

   BEGIN
      g_module_name := 'update_address';

      /** Version 1.3.1
      OPEN c_pre_address;
      FETCH c_pre_address
      INTO r_pre_address;
      CLOSE c_pre_address;
      **/

      /** Version 1.3.1                                                             **/
      /** This loop is to terminate "all" the primary addresses a person may have,  **/
      /** it is not common, but we found a few cases that had more than one active  **/
      /** primary address and it?s better to have all bases covered.                **/
      FOR r_pre_address IN c_pre_address -- Added by NMondada 05-NOV-2008
      LOOP
          -- Modfied by NMondada 05-NOV-2008
          /*l_change := 'N';

          IF p_address_line1 IS NOT NULL
          THEN
             IF NVL (r_pre_address.address_line1, 'XXX') <> p_address_line1
             THEN
                l_change := 'Y';
             END IF;
          END IF;

          IF p_address_line2 IS NOT NULL

          THEN
             IF NVL (r_pre_address.address_line2, 'XXX') <> p_address_line2
             THEN
                l_change := 'Y';
             END IF;
          END IF;

          IF p_city IS NOT NULL
          THEN
             IF NVL (r_pre_address.town_or_city, 'XXX') <> p_city
             THEN
                l_change := 'Y';
             END IF;

          END IF;

          IF p_region_1 IS NOT NULL
          THEN
             IF NVL (r_pre_address.region_1, 'XXX') <> p_region_1
             THEN
                l_change := 'Y';
             END IF;
          END IF;

          IF p_region_2 IS NOT NULL
          THEN
             IF NVL (r_pre_address.region_2, 'XXX') <> p_region_2

             THEN
                l_change := 'Y';
             END IF;
          END IF;

          IF p_postal_code IS NOT NULL
          THEN
             IF NVL (r_pre_address.postal_code, 'XXX') <> p_postal_code
             THEN
                l_change := 'Y';
             END IF;
          END IF;


          IF l_change = 'Y'
          THEN
             DBMS_OUTPUT.PUT_LINE ('Address Changed.');
             DBMS_OUTPUT.PUT_LINE (   'ObjectVN:'
                                   || r_pre_address.object_version_number
                                  );
             DBMS_OUTPUT.PUT_LINE ('Address ID:' || r_pre_address.address_id);
             DBMS_OUTPUT.PUT_LINE ('Address Start Date:'
                                   || r_pre_address.date_from
                                  );
          ELSE
             DBMS_OUTPUT.PUT_LINE ('Address Not Changed.');
             RETURN;

          END IF;
          */ --

          /** If the person has a primary address, terminate first all  **/
          /** his secondary addresses and then the primary address.     **/


          IF r_pre_address.address_id IS NOT NULL
          THEN

             /** If we have secondary addresses, terminate them first **/
             FOR r_pre_sec_address IN c_pre_sec_address
             LOOP

                 IF r_pre_sec_address.address_id IS NOT NULL
                 THEN


                    Tt_Hrms_Api_Utility_Pkg.update_address
                                  (ip_effective_date      => p_effective_date,
                                   ip_address_id          => r_pre_sec_address.address_id,
                                   ip_ovn                 => r_pre_sec_address.object_version_number,
                                   ip_date_to             => p_effective_date - 1,
                                   op_success_flag        => l_success_flag,
                                   op_error_message       => l_error_message
                                  );


                 END IF;

             END LOOP;

             /** Terminate primary addresses **/
             Tt_Hrms_Api_Utility_Pkg.update_address
                                  (ip_effective_date      => p_effective_date,
                                   ip_address_id          => r_pre_address.address_id,
                                   ip_ovn                 => r_pre_address.object_version_number,
                                   ip_date_to             => p_effective_date - 1,
                                   op_success_flag        => l_success_flag,
                                   op_error_message       => l_error_message
                                  );

             IF l_success_flag = 'N'
             THEN
                RAISE api_error;
             END IF;

          END IF;

          DBMS_OUTPUT.PUT_LINE ('Person ID:' || p_person_id);
          DBMS_OUTPUT.PUT_LINE (   'Region1:'
                                || p_region_1
                                || '-'
                                || 'Region2:'
                                || p_region_2
                               );

           DBMS_OUTPUT.PUT_LINE ('Before rehire address create:' );

      END LOOP;
	  /* Added as part of 7.7 */

      if  p_business_group_id = 5054 and apps.ttec_get_bg (p_business_group_id, p_organization_id) = 67246 /*8.5 Colombia Address*/
        THEN
         v_style         := 'CO_GLB';

      elsIF p_business_group_id = 5054 and apps.ttec_get_bg (p_business_group_id, p_organization_id) != 67246 THEN
        v_style := 'CR_GLB';
      ELSE
        v_style := p_style;
      END IF;
      /** End of Version 1.3.1 **/
     Fnd_File.put_line(Fnd_File.LOG, 'Before rehire address create:');
      create_address (p_business_group_id         => p_business_group_id,
                      p_person_id                 => p_person_id,
                      p_effective_date            => p_effective_date,
                      p_style                     => v_style, --p_style, -- Modified by Venkat
                      p_effective_start_date      => p_effective_date,
                      p_address_line1             => p_address_line1,
                      p_address_line2             => p_address_line2,
                      p_city                      => p_city,
                      --
                      p_region_1                  => p_region_1,
                      p_region_2                  => p_region_2,
                      --
                      p_postal_code               => p_postal_code,
                      p_country                   => p_country,
                      p_landline                  => p_landline,
                      p_mobile                    => p_mobile,
                      p_email                     => p_email,
                      p_success_flag              => l_success_flag,
                      p_error_message             => l_error_message,
                      /* Version 1.3 - ZA Integration */
                      p_organization_id           => p_organization_id,
                      /* Version 1.4 - ARG Integration */
                      p_stateprovincedes          => p_stateprovincedes,
					  p_stateprovincecode         => p_stateprovincecode,           --8.6
                      p_addressdistrict           => p_addressdistrict,
                      p_addressneighborhood       => p_addressneighborhood,
                      p_addressmunicipality       => p_addressmunicipality,
                       /* Version 5.0 - Motif Indi Integration */
                      P_LIVEINADDRSINCE           => P_LIVEINADDRSINCE,
                      P_CORRESPADDRESS	          => P_CORRESPADDRESS,
                      P_CORRESPADDRESS2	          => P_CORRESPADDRESS2,
                      P_CORRESPCITY	              => P_CORRESPCITY,
                      P_CORRESPSTATE              => P_CORRESPSTATE,
                      P_CORRESPZIPCODE	          => P_CORRESPZIPCODE,
                      P_CORRESPCOUNTRYCODE        => P_CORRESPCOUNTRYCODE
                      );

       DBMS_OUTPUT.PUT_LINE ('After rehire address create:' );



   EXCEPTION
      WHEN OTHERS
      THEN

         Fnd_File.put_line(Fnd_File.LOG, 'Error information:'||DBMS_UTILITY.FORMAT_ERROR_STACK );
         IF l_success_flag = 'N'
         THEN
            g_error_message := 'Rehire update address api: ' || l_error_message;

          Fnd_File.put_line(Fnd_File.LOG, 'Rehire update address api:'||DBMS_UTILITY.FORMAT_ERROR_STACK );

         ELSE

        g_error_message := 'Other Error at Rehire update address api: ' || SQLERRM;
        Fnd_File.put_line(Fnd_File.LOG, 'Other Error at Rehire update address api:'||DBMS_UTILITY.FORMAT_ERROR_STACK );

         END IF;

         g_label2           := 'Employee Number';
         g_secondary_column := p_employee_number;
         RAISE skip_record;
   END;


    /*************************************************************************************************************
    -- PROCEDURE create_phone
    -- Author: Ibrahim Konak
    -- Date:  Feb 26 2007
    -- Parameters:
    -- Description: This procedure creates phone record for the employee.
    **************************************************************************************************************/
   PROCEDURE create_phone (
      p_person_id              IN   NUMBER,
      p_effective_start_date   IN   VARCHAR2,
      p_phone_type             IN   VARCHAR2,
      p_phone_number           IN   VARCHAR2
   )
   IS
      l_phone_id        per_phones.phone_id%TYPE;
      l_success_flag    g_success_flag%TYPE;
      l_error_message   g_error_message%TYPE;

   BEGIN
      g_module_name := 'create_phone';

      Tt_Hrms_Api_Utility_Pkg.create_phone
                          (ip_validate              => FALSE,
                           ip_effective_start_date  => p_effective_start_date,
                           ip_phone_type            => p_phone_type,
                           --'W1',  --'H1',
                           ip_phone_number          => p_phone_number,
                           ip_person_id             => p_person_id,
                           --ip_parent_table          => NULL,
                           ip_effective_date        => p_effective_start_date,
                           op_phone_id              => l_phone_id,
                           op_success_flag          => l_success_flag,
                           op_error_message         => l_error_message
                          );

      IF l_success_flag = 'N'
      THEN

         RAISE api_error;

      END IF;

   EXCEPTION
      WHEN api_error
      THEN
         g_error_message    := 'Warning api phone creation' || l_error_message;
         g_label2           := 'Phone';
         g_secondary_column := p_phone_number;

         --cust.ttec_process_error (c_application_code,				-- Commented code by IXPRAVEEN-ARGANO,14-july-2023
         apps.ttec_process_error (c_application_code,               --  code Added by IXPRAVEEN-ARGANO,   14-july-2023
                                  c_interface,
                                  c_program_name,
                                  g_module_name,
                                  c_warning_status,
                                  SQLCODE,
                                  g_error_message,
                                  g_label1,
                                  g_primary_column,
                                  g_label2,
                                  g_secondary_column
                                 );

         print_line (   RPAD (NVL (g_primary_column, ' '), 10)
                     || ' '
                     || RPAD (NVL (g_label2, ' '), 17)
                     || ' '
                     || RPAD (NVL (g_secondary_column, ' '), 16)
                     || ' '
                     || RPAD (NVL (g_error_message, ' '), 51)
                    );
      WHEN OTHERS
      THEN
         g_error_message    := 'Warning other phone creation' || l_error_message;
         g_label2           := 'Phone';
         g_secondary_column := p_phone_number;
         RAISE skip_record;
   END;

    /*************************************************************************************************************
    -- PROCEDURE update_phone
    -- Author: Ibrahim Konak
    -- Date:  Feb 26 2007
    -- Parameters:
    -- Description: This procedure updates employee phone if changed.
    **************************************************************************************************************/
   PROCEDURE update_phone (
      p_person_id         IN   NUMBER,
      p_employee_number   IN   VARCHAR2,
      p_effective_date    IN   DATE,
      p_phone_type        IN   VARCHAR2,
      p_phone_number      IN   VARCHAR2
   )
   IS
      l_success_flag    g_success_flag%TYPE;
      l_error_message   g_error_message%TYPE;

      CURSOR c_pre_phone
      IS
         SELECT *
           FROM per_phones
          WHERE phone_type = p_phone_type
            AND parent_id = p_person_id
            AND parent_table = 'PER_ALL_PEOPLE_F'
            AND p_effective_date BETWEEN date_from
			    AND NVL (date_to, '31-DEC-4712' );

      r_pre_phone       c_pre_phone%ROWTYPE;

   BEGIN
      g_module_name := 'update_phone';

      OPEN c_pre_phone;

      FETCH c_pre_phone
       INTO r_pre_phone;

      CLOSE c_pre_phone;


      IF NVL (r_pre_phone.phone_number, 'XXX') <> p_phone_number
      THEN
         DBMS_OUTPUT.PUT_LINE ('Phone Changed.');
         DBMS_OUTPUT.PUT_LINE ('ObjectVN:'
                               || r_pre_phone.object_version_number
                              );
         DBMS_OUTPUT.PUT_LINE ('Phone ID:' || r_pre_phone.phone_id);
         DBMS_OUTPUT.PUT_LINE ('Phone Start Date:' || r_pre_phone.date_from);
      ELSE

         DBMS_OUTPUT.PUT_LINE ('Phone Not Changed.');
         RETURN;

      END IF;


      IF r_pre_phone.phone_id IS NOT NULL
      THEN
         Tt_Hrms_Api_Utility_Pkg.update_phone
                (ip_effective_date      => p_effective_date,
                 ip_ovn                 => r_pre_phone.object_version_number,
                 ip_date_to             => p_effective_date - 1,
                 ip_phone_id            => r_pre_phone.phone_id,
                 op_success_flag        => l_success_flag,
                 op_error_message       => l_error_message
                );


         IF l_success_flag = 'N'
         THEN

            RAISE api_error;

         END IF;

      END IF;

      create_phone (p_person_id                 => p_person_id,
                    p_effective_start_date      => p_effective_date,
                    p_phone_type                => p_phone_type,
                    p_phone_number              => p_phone_number
                   );

      IF l_success_flag = 'N'

      THEN
         RAISE api_error;
      END IF;


   EXCEPTION
      WHEN api_error
      THEN
         g_error_message    := 'Error at update phone api' || l_error_message;
         g_label2           := 'Employee Number';
         g_secondary_column := p_employee_number;
         RAISE skip_record;
      WHEN OTHERS
      THEN
         g_error_message    := 'Other Error at update phone api' || SQLERRM;
         g_label2           := 'Employee Number';
         g_secondary_column := p_employee_number;
         RAISE skip_record;
   END;
/* 5.0.9 Begin */
    /*************************************************************************************************************
    -- PROCEDURE create_ind_parents_details
    -- Author: Christiane
    -- Date:  May 18, 2018
    -- Parameters:
    -- Description: This procedure creates India Parents Details specifically for candidate from India business group
    **************************************************************************************************************/
   PROCEDURE  create_ind_parents_details( p_person_id              IN   NUMBER,
                                          p_father_last_name       IN   VARCHAR2,
                                          p_father_middle_names    IN   VARCHAR2,
                                          p_father_first_name      IN   VARCHAR2,
                                          p_mother_last_name       IN   VARCHAR2,
                                          p_mother_middle_names    IN   VARCHAR2,
                                          p_mother_first_name      IN   VARCHAR2)
   IS
      o_object_version_number   per_people_extra_info.object_version_number%TYPE;
      o_person_extra_info_id    per_people_extra_info.person_extra_info_id%TYPE;

   BEGIN
      BEGIN

                 o_person_extra_info_id  := NULL;
                 o_object_version_number := NULL;

                 hr_person_extra_info_api.create_person_extra_info
                                (p_validate                          => FALSE,
                                 p_person_id                         => p_person_id,
                                 p_information_type                  => 'TTEC_IND_PARENTS_DETAILS',
                                 p_pei_information_category          => 'TTEC_IND_PARENTS_DETAILS',
                                 p_pei_information2                  => p_father_last_name,
                                 p_pei_information3                  => p_father_middle_names,
                                 p_pei_information4                  => p_father_first_name,
                                 p_pei_information5                  => p_mother_last_name,
                                 p_pei_information6                  => p_mother_middle_names,
                                 p_pei_information7                  => p_mother_first_name,
                                 --OUT Parameters
                                 p_person_extra_info_id              => o_person_extra_info_id ,
                                 p_object_version_number             => o_object_version_number
                                );

      EXCEPTION
       WHEN OTHERS THEN
                  g_error_message := 'Error in extra info API:' || SQLERRM;
                  g_label2 := 'Person_id';
                  g_secondary_column := p_person_id ;
                  RAISE skip_record;
       END;
  END create_ind_parents_details;
    /*************************************************************************************************************
    -- PROCEDURE update_ind_parents_details
    -- Author: Christiane Chan
    -- Date:  May 24 2018
    -- Parameters:
    -- Description: This procedure updates India employee parent details if changed.
    **************************************************************************************************************/
   PROCEDURE  update_ind_parents_details( p_person_id              IN   NUMBER,
                                          p_father_last_name       IN   VARCHAR2,
                                          p_father_middle_names    IN   VARCHAR2,
                                          p_father_first_name      IN   VARCHAR2,
                                          p_mother_last_name       IN   VARCHAR2,
                                          p_mother_middle_names    IN   VARCHAR2,
                                          p_mother_first_name      IN   VARCHAR2)
   IS
      o_object_version_number   per_people_extra_info.object_version_number%TYPE;
      o_person_extra_info_id    per_people_extra_info.person_extra_info_id%TYPE;

      CURSOR c_pre_per_extra_info
      IS
         SELECT *
           FROM   APPS.PER_PEOPLE_EXTRA_INFO
          WHERE person_id = p_person_id
            AND information_type = 'TTEC_IND_PARENTS_DETAILS'
            AND pei_information_category = 'TTEC_IND_PARENTS_DETAILS'
            AND rownum < 2
           ORDER BY object_version_number desc;

      r_pre_per_extra_info       c_pre_per_extra_info%ROWTYPE;

   BEGIN
      g_module_name := 'update_parent_detail';

      OPEN c_pre_per_extra_info;

      FETCH c_pre_per_extra_info
       INTO r_pre_per_extra_info;

      CLOSE c_pre_per_extra_info;


      IF  NVL (r_pre_per_extra_info.pei_information2, 'XXX') <>  NVL(p_father_last_name, 'XXX') OR
            NVL (r_pre_per_extra_info.pei_information3, 'XXX') <>  NVL(p_father_middle_names, 'XXX') OR
            NVL (r_pre_per_extra_info.pei_information4, 'XXX') <>  NVL(p_father_first_name, 'XXX') OR
            NVL (r_pre_per_extra_info.pei_information5, 'XXX') <>  NVL(p_mother_last_name, 'XXX')  OR
            NVL (r_pre_per_extra_info.pei_information6, 'XXX') <>  NVL(p_mother_middle_names, 'XXX') OR
            NVL (r_pre_per_extra_info.pei_information7, 'XXX') <>  NVL(p_mother_first_name, 'XXX')
      THEN
         DBMS_OUTPUT.PUT_LINE ('Parent Detail Changed.');
         DBMS_OUTPUT.PUT_LINE ('ObjectVN:'
                               || r_pre_per_extra_info.object_version_number
                              );
      ELSE

         DBMS_OUTPUT.PUT_LINE ('Parent Detail Not Changed.');
         RETURN;

      END IF;


      BEGIN

                 o_person_extra_info_id  := r_pre_per_extra_info.person_extra_info_id;
                 o_object_version_number := r_pre_per_extra_info.object_version_number;

                 hr_person_extra_info_api.update_person_extra_info
                                (p_validate                          => FALSE,
                                 p_person_extra_info_id              => o_person_extra_info_id,
                                 -- In / Out
                                 p_object_version_number             => o_object_version_number,
                                 -- In
                                 p_pei_information_category          => 'TTEC_IND_PARENTS_DETAILS',
                                 p_pei_information2                  => p_father_last_name,
                                 p_pei_information3                  => p_father_middle_names,
                                 p_pei_information4                  => p_father_first_name,
                                 p_pei_information5                  => p_mother_last_name,
                                 p_pei_information6                  => p_mother_middle_names,
                                 p_pei_information7                  => p_mother_first_name
                                );

      EXCEPTION
       WHEN OTHERS THEN
                  g_error_message := 'Error in extra info API:' || SQLERRM;
                  g_label2 := 'Person_id';
                  g_secondary_column := p_person_id ;
                  RAISE skip_record;
       END;


   EXCEPTION
      WHEN NO_DATA_FOUND
      THEN
              create_ind_parents_details( p_person_id              => p_person_id,
                                          p_father_last_name       => p_father_last_name,
                                          p_father_middle_names    => p_father_middle_names,
                                          p_father_first_name      => p_father_first_name,
                                          p_mother_last_name       => p_mother_last_name,
                                          p_mother_middle_names    => p_mother_middle_names,
                                          p_mother_first_name      => p_mother_first_name);
      WHEN OTHERS
      THEN
         g_error_message    := 'Other Error at update_ind_parents_details: ' || SQLERRM;
                  g_label2 := 'Person_id';
                  g_secondary_column := p_person_id ;
         RAISE skip_record;
   END;
/* 5.0.9 End */
/* 7.3.2 Begin */
    /*************************************************************************************************************
    -- PROCEDURE create_grc_dep_parents_details
    -- Author: Christiane
    -- Date:  Nov 11, 2020
    -- Parameters:
    -- Description: This procedure creates Greek Dependant and Parents Details specifically for candidate from Greece business group
    **************************************************************************************************************/
   PROCEDURE  create_grc_dep_parents_details( p_person_id              IN   NUMBER,
                                          p_no_dependant_child     IN   VARCHAR2,
                                          p_father_last_name       IN   VARCHAR2,
                                          p_father_middle_names    IN   VARCHAR2,
                                          p_father_first_name      IN   VARCHAR2,
                                          p_mother_last_name       IN   VARCHAR2,
                                          p_mother_middle_names    IN   VARCHAR2,
                                          p_mother_first_name      IN   VARCHAR2)
   IS
      o_object_version_number   per_people_extra_info.object_version_number%TYPE;
      o_person_extra_info_id    per_people_extra_info.person_extra_info_id%TYPE;

   BEGIN

   g_module_name := 'cr_grc_dep_parent_det';

      BEGIN

                 o_person_extra_info_id  := NULL;
                 o_object_version_number := NULL;

                 hr_person_extra_info_api.create_person_extra_info
                                (p_validate                          => FALSE,
                                 p_person_id                         => p_person_id,
                                 p_information_type                  => 'GRC_DEPENDENTS_PARENTS_DETAILS',
                                 p_pei_information_category          => 'GRC_DEPENDENTS_PARENTS_DETAILS',
                                 p_pei_information1                  => p_no_dependant_child,
                                 p_pei_information2                  => p_father_last_name,
                                 p_pei_information3                  => p_father_middle_names,
                                 p_pei_information4                  => p_father_first_name,
                                 p_pei_information5                  => p_mother_last_name,
                                 p_pei_information6                  => p_mother_middle_names,
                                 p_pei_information7                  => p_mother_first_name,
                                 --OUT Parameters
                                 p_person_extra_info_id              => o_person_extra_info_id ,
                                 p_object_version_number             => o_object_version_number
                                );

      EXCEPTION
       WHEN OTHERS THEN
                  g_error_message := 'Error in extra info API:' || SQLERRM;
                  fnd_file.put_line(fnd_file.log,'ERROR while creating parent details');
                  g_label2 := 'Person_id';
                  g_secondary_column := p_person_id ;
                  RAISE skip_record;
       END;
  END create_grc_dep_parents_details;

 /******************************************************************
    -- PROCEDURE create_pl_experience_details
    -- Author: Rajesh Koneru
    -- Date:  Jan 29, 2021
    -- Parameters:
    -- Description: This procedure creates ind Exp details for poland
*********************************************************************/

    PROCEDURE create_pl_experience_details(
                                p_business_group_id  IN  NUMBER,
                                p_person_id          IN  NUMBER,
                                p_effective_date     IN  DATE,
                                p_segment_1          IN  VARCHAR2,
                                p_segment_2          IN  VARCHAR2
                              ) IS


    v_analysis_criteria_id      per_person_analyses.analysis_criteria_id%TYPE;
    v_person_analysis_id        per_person_analyses.person_analysis_id%TYPE;
    v_pea_object_version_number per_person_analyses.object_version_number%TYPE;
    v_id_flex   fnd_id_flex_structures_vl.id_flex_num%TYPE;

    l_success_flag              g_success_flag%TYPE;
    l_error_message             g_error_message%TYPE;
    l_segment1                  per_analysis_criteria.segment1%TYPE;



    CURSOR c_id_flex IS
    SELECT id_flex_num
    FROM fnd_id_flex_structures_vl
    WHERE  ID_FLEX_STRUCTURE_CODE = 'PL_INDUSTRY_EXPERIENCE';

   BEGIN
      g_module_name := 'PL_INDUSTRY_EXPERIENCE';

       OPEN c_id_flex;
       FETCH c_id_flex INTO v_id_flex;
       CLOSE c_id_flex;

        hr_sit_api.create_sit
            (p_person_id                  =>  p_person_id,
             p_business_group_id          =>  p_business_group_id,
             p_id_flex_num                =>  v_id_flex,
             p_effective_date             =>  p_effective_date,
             p_date_from                  =>  p_effective_date,
             p_segment1                   =>  p_segment_1,
             p_segment2                   =>  p_segment_2,
             p_analysis_criteria_id       =>  v_analysis_criteria_id,
             p_person_analysis_id         =>  v_person_analysis_id,
             p_pea_object_version_number  =>  v_pea_object_version_number);

            l_success_flag := 'Y';

    EXCEPTION
    WHEN OTHERS
    THEN
        l_success_flag      := 'N';
        l_error_message     := SQLERRM;
        g_error_message     := 'Error others in Create Poland Industry Experience' || SQLERRM;
        g_label2            := 'Person Id';
        g_secondary_column  := p_person_id;
        RAISE skip_record;
   END  create_pl_experience_details;

/******************************************************************
    -- PROCEDURE update_pl_experience_details
    -- Author: Rajesh Koneru
    -- Date:  Feb 12, 2021
    -- Parameters:
    -- Description: This procedure Updates Industrila exp for poland
*********************************************************************/
PROCEDURE update_pl_experience_details ( p_business_group_id  IN  NUMBER,
                                     p_person_id          IN  NUMBER,
                                     p_employee_number    IN  VARCHAR2,
                                     p_effective_date     IN  DATE,
                                     p_segment_1          IN  VARCHAR2,
                                     p_segment_2          IN  VARCHAR2
                                      )
   IS
      l_success_flag    g_success_flag%TYPE;
      l_error_message   g_error_message%TYPE;

      v_date_to             date;
      v_previous_date_from         date;

      v_pea_object_version_number     NUMBER;
      v_id_flex_num                   fnd_id_flex_structures_vl.id_flex_num%TYPE;
      v_person_analysis_id            per_person_analyses.person_analysis_id%TYPE;
      v_analysis_criteria_id          per_analysis_criteria.analysis_criteria_id%TYPE;

      CURSOR c_id_flex IS
      SELECT id_flex_num
      FROM fnd_id_flex_structures_vl
      WHERE  ID_FLEX_STRUCTURE_CODE = 'PL_INDUSTRY_EXPERIENCE';


      CURSOR c_pre_contract IS
        SELECT  pa.person_analysis_id
                ,ac.ANALYSIS_CRITERIA_ID ,pa.date_from
                ,pa.object_version_number
		--START R12.2 Upgrade Remediation		
         /* FROM  hr.per_person_analyses pa,				-- Commented code by IXPRAVEEN-ARGANO,14-july-2023
                hr.per_analysis_criteria ac*/
		  FROM  APPS.per_person_analyses pa,				--  code Added by IXPRAVEEN-ARGANO,   14-july-2023
                apps.per_analysis_criteria ac	
		--END R12.2.12 Upgrade remediation
         WHERE pa.analysis_criteria_id = ac.analysis_criteria_id
           AND pa.id_flex_num = v_id_flex_num
           AND pa.person_id = p_person_id
           AND date_from = (SELECT MAX(pa1.date_from)
                            --FROM  hr.per_person_analyses pa1			-- Commented code by IXPRAVEEN-ARGANO,14-july-2023
                            FROM  apps.per_person_analyses pa1          --  code Added by IXPRAVEEN-ARGANO,   14-july-2023
                            where pa1.id_flex_num = v_id_flex_num
                            AND pa1.person_id = p_person_id);

   BEGIN
      g_module_name := 'update_grc_tax_auth_dept_DOY';

       OPEN c_id_flex;
       FETCH c_id_flex INTO v_id_flex_num;
       CLOSE c_id_flex;

       OPEN c_pre_contract;
       FETCH c_pre_contract INTO v_person_analysis_id,v_analysis_criteria_id,v_previous_date_from
             ,v_pea_object_version_number;
       CLOSE c_pre_contract;


      IF v_person_analysis_id IS NOT NULL THEN


          v_date_to := p_effective_date - 1;

          IF v_previous_date_from >= v_date_to THEN

              /* FORCED TO End date the existing record with the day before current effective date*/

              hr_sit_api.update_sit
                        (p_validate                     => FALSE
                        ,p_person_analysis_id           => v_person_analysis_id
                        ,p_pea_object_version_number    => v_pea_object_version_number
                        ,p_analysis_criteria_id         => v_analysis_criteria_id
                        ,p_date_from                    => v_date_to
                        ,p_date_to                      => v_date_to
                        );


          ELSE

               /* End date the existing record */
               hr_sit_api.update_sit
                            (p_validate                     => FALSE
                            ,p_person_analysis_id           => v_person_analysis_id
                            ,p_pea_object_version_number    => v_pea_object_version_number
                            ,p_analysis_criteria_id         => v_analysis_criteria_id
                            ,p_date_to                      => v_date_to
                            );
          END IF;

      END IF;

        /* Rehire - Create hireIQ' */

        v_analysis_criteria_id := NULL;

        hr_sit_api.create_sit
            (p_person_id                  =>  p_person_id,
             p_business_group_id          =>  p_business_group_id,
             p_id_flex_num                =>  v_id_flex_num,
             p_effective_date             =>  p_effective_date,
             p_date_from                  =>  p_effective_date,
             p_segment1                   =>  p_segment_1,
             p_segment2                   =>  p_segment_2,
             p_analysis_criteria_id       =>  v_analysis_criteria_id,
             p_person_analysis_id         =>  v_person_analysis_id,
             p_pea_object_version_number  =>  v_pea_object_version_number);

   EXCEPTION
      WHEN api_error
      THEN
         g_error_message    := 'Error at Update poland experience details' || l_error_message;
         g_label2           := 'Employee Number';
         g_secondary_column := p_employee_number;
         RAISE skip_record;
      WHEN OTHERS
      THEN
         g_error_message    := 'Other Error at poland experience details' || SQLERRM;
         g_label2           := 'Employee Number';
         g_secondary_column := p_employee_number;
         RAISE skip_record;
   END update_pl_experience_details;

    /*************************************************************************************************************
    -- PROCEDURE update_grc_dep_parents_details
    -- Author: Christiane Chan
    -- Date:  Nov 11, 2020
    -- Parameters:
    -- Description: This procedure updates Greece employee dependant/parent details if changed.
    **************************************************************************************************************/
   PROCEDURE  update_grc_dep_parents_details( p_person_id              IN   NUMBER,
                                          p_no_dependant_child     IN   VARCHAR2,
                                          p_father_last_name       IN   VARCHAR2,
                                          p_father_middle_names    IN   VARCHAR2,
                                          p_father_first_name      IN   VARCHAR2,
                                          p_mother_last_name       IN   VARCHAR2,
                                          p_mother_middle_names    IN   VARCHAR2,
                                          p_mother_first_name      IN   VARCHAR2)
   IS
      o_object_version_number   per_people_extra_info.object_version_number%TYPE;
      o_person_extra_info_id    per_people_extra_info.person_extra_info_id%TYPE;

      CURSOR c_pre_per_extra_info
      IS
         SELECT *
           FROM   APPS.PER_PEOPLE_EXTRA_INFO
          WHERE person_id = p_person_id
            AND information_type = 'GRC_DEPENDENTS_PARENTS_DETAILS'
            AND pei_information_category = 'GRC_DEPENDENTS_PARENTS_DETAILS'
            AND rownum < 2
           ORDER BY object_version_number desc;

      r_pre_per_extra_info       c_pre_per_extra_info%ROWTYPE;

   BEGIN
      g_module_name := 'upd_grc_dep_parent_det';
      Fnd_File.put_line(Fnd_File.LOG, 'Before opening cursor');
      OPEN c_pre_per_extra_info;

      FETCH c_pre_per_extra_info
       INTO r_pre_per_extra_info;

      CLOSE c_pre_per_extra_info;
      Fnd_File.put_line(Fnd_File.LOG, 'After Closing the cursor');

      IF    NVL (r_pre_per_extra_info.pei_information1, '0')     <>  NVL(p_no_dependant_child,'0') OR
            NVL (r_pre_per_extra_info.pei_information2, 'XXX') <>  NVL(p_father_last_name, 'XXX') OR
            NVL (r_pre_per_extra_info.pei_information3, 'XXX') <>  NVL(p_father_middle_names, 'XXX') OR
            NVL (r_pre_per_extra_info.pei_information4, 'XXX') <>  NVL(p_father_first_name, 'XXX') OR
            NVL (r_pre_per_extra_info.pei_information5, 'XXX') <>  NVL(p_mother_last_name, 'XXX')  OR
            NVL (r_pre_per_extra_info.pei_information6, 'XXX') <>  NVL(p_mother_middle_names, 'XXX') OR
           NVL (r_pre_per_extra_info.pei_information7, 'XXX')  <>  NVL(p_mother_first_name, 'XXX')
      THEN
         DBMS_OUTPUT.PUT_LINE ('Parent Detail Changed.');
         Fnd_File.put_line(Fnd_File.LOG, 'Parent Detail Changed.');
         DBMS_OUTPUT.PUT_LINE ('ObjectVN:'
                               || r_pre_per_extra_info.object_version_number
                              );
      ELSE
         Fnd_File.put_line(Fnd_File.LOG, 'Dependant/Parent Detail Not Changed.');
         DBMS_OUTPUT.PUT_LINE ('Dependant/Parent Detail Not Changed.');
         RETURN;

      END IF;


      BEGIN

                 o_person_extra_info_id  := r_pre_per_extra_info.person_extra_info_id;
                 o_object_version_number := r_pre_per_extra_info.object_version_number;

                  Fnd_File.put_line(Fnd_File.LOG, 'Checking o_person_extra_info_id:'||o_person_extra_info_id);
                   Fnd_File.put_line(Fnd_File.LOG, 'Checking o_object_version_number:'||o_object_version_number );
      if r_pre_per_extra_info.person_extra_info_id is not null
      then
                 hr_person_extra_info_api.update_person_extra_info
                                (p_validate                          => FALSE,
                                 p_person_extra_info_id              => o_person_extra_info_id,
                                 -- In / Out
                                 p_object_version_number             => o_object_version_number,
                                 -- In
                                 p_pei_information_category          => 'GRC_DEPENDENTS_PARENTS_DETAILS',
                                 p_pei_information1                  => p_no_dependant_child,
                                 p_pei_information2                  => p_father_last_name,
                                 p_pei_information3                  => p_father_middle_names,
                                 p_pei_information4                  => p_father_first_name,
                                 p_pei_information5                  => p_mother_last_name,
                                 p_pei_information6                  => p_mother_middle_names,
                                 p_pei_information7                  => p_mother_first_name
                                );
          else

          create_grc_dep_parents_details( p_person_id              => p_person_id,
                                          p_no_dependant_child     => p_no_dependant_child,
                                          p_father_last_name       => p_father_last_name,
                                          p_father_middle_names    => p_father_middle_names,
                                          p_father_first_name      => p_father_first_name,
                                          p_mother_last_name       => p_mother_last_name,
                                          p_mother_middle_names    => p_mother_middle_names,
                                          p_mother_first_name      => p_mother_first_name);

          end if;


      EXCEPTION
       WHEN OTHERS THEN
                  g_error_message := 'Error in extra info API:' || SQLERRM;
                  fnd_file.put_line(fnd_file.log,'ERROR while Updating parent details');
                  g_label2 := 'Person_id';
                  g_secondary_column := p_person_id ;
                  RAISE skip_record;
       END;


   EXCEPTION
      WHEN NO_DATA_FOUND
      THEN
              create_grc_dep_parents_details( p_person_id              => p_person_id,
                                          p_no_dependant_child     => p_no_dependant_child,
                                          p_father_last_name       => p_father_last_name,
                                          p_father_middle_names    => p_father_middle_names,
                                          p_father_first_name      => p_father_first_name,
                                          p_mother_last_name       => p_mother_last_name,
                                          p_mother_middle_names    => p_mother_middle_names,
                                          p_mother_first_name      => p_mother_first_name);
      WHEN OTHERS
      THEN


          Fnd_File.put_line(Fnd_File.LOG, 'Error information:'||DBMS_UTILITY.FORMAT_ERROR_STACK );
         g_error_message    := 'Other Error at update_grc_dep_parents_details: ' || SQLERRM;
                  g_label2 := 'Person_id';
                  g_secondary_column := p_person_id ;
         RAISE skip_record;
   END;
/* 7.3.2 End */
/* 7.3.3 Begin */
    /*************************************************************************************************************
    -- PROCEDURE create_work_permit_details
    -- Author: Christiane
    -- Date:  Nov 12, 2020
    -- Parameters:
    -- Description: This procedure creates Work Permit Details specifically for candidate from specific BG who are required
    --                        to report these info
    **************************************************************************************************************/
   PROCEDURE  create_work_permit_details( p_person_id              IN   NUMBER,
                                          p_work_permit_number         IN   VARCHAR2,
                                          p_work_permit_expiry_date  IN   VARCHAR2)
   IS
      o_object_version_number   per_people_extra_info.object_version_number%TYPE;
      o_person_extra_info_id    per_people_extra_info.person_extra_info_id%TYPE;
      p_work_permi_date_seg varchar2(100):=NULL;

   BEGIN
      g_module_name := 'create_work_permit';
      BEGIN
                 o_person_extra_info_id  := NULL;
                 o_object_version_number := NULL;

                 IF p_work_permit_expiry_date IS NULL
                 THEN
                 p_work_permi_date_seg:=null;
                 ELSE
                 p_work_permi_date_seg:=to_char(to_date(p_work_permit_expiry_date,'DD-MON-YY'),'yyyy/mm/dd')||'00:00:00';
                 END IF;

                 hr_person_extra_info_api.create_person_extra_info
                                (p_validate                          => FALSE,
                                 p_person_id                         => p_person_id,
                                 p_information_type                  => 'GRC_WORK_PERMITS',
                                 p_pei_information_category          => 'GRC_WORK_PERMITS',
                                 p_pei_information1                  => p_work_permit_number,
                                 p_pei_information2                  => p_work_permi_date_seg,
                                 --OUT Parameters
                                 p_person_extra_info_id              => o_person_extra_info_id ,
                                 p_object_version_number             => o_object_version_number
                                );

      EXCEPTION
       WHEN OTHERS THEN
                  g_error_message := 'Error in extra info API:' || SQLERRM;
                  fnd_file.put_line(fnd_file.log,'ERROR while Creating Work Permit details');
                  g_label2 := 'Person_id';
                  g_secondary_column := p_person_id ;
                  RAISE skip_record;
       END;
  END create_work_permit_details;
    /*************************************************************************************************************
    -- PROCEDURE update_work_permit_details
    -- Author: Christiane Chan
    -- Date:  Nov 12, 2020
    -- Parameters:
    -- Description: This procedure updates employee work permit details if changed.
    **************************************************************************************************************/
   PROCEDURE  update_work_permit_details( p_person_id              IN   NUMBER,
                                          p_work_permit_number          IN   VARCHAR2,
                                          p_work_permit_expiry_date   IN   VARCHAR2)
   IS
      o_object_version_number   per_people_extra_info.object_version_number%TYPE;
      o_person_extra_info_id    per_people_extra_info.person_extra_info_id%TYPE;
      p_work_permi_date_seg varchar2(100):=NULL;

      CURSOR c_pre_per_extra_info
      IS
         SELECT *
           FROM   APPS.PER_PEOPLE_EXTRA_INFO
          WHERE person_id = p_person_id
            AND information_type = 'GRC_WORK_PERMITS'
            AND pei_information_category = 'GRC_WORK_PERMITS'
            AND rownum < 2
           ORDER BY object_version_number desc;

      r_pre_per_extra_info       c_pre_per_extra_info%ROWTYPE;

   BEGIN
      g_module_name := 'upd_work_permit_det';

      OPEN c_pre_per_extra_info;

      FETCH c_pre_per_extra_info
       INTO r_pre_per_extra_info;

      CLOSE c_pre_per_extra_info;

                 IF p_work_permit_expiry_date IS NULL
                 THEN
                 p_work_permi_date_seg:=null;
                 ELSE
                 p_work_permi_date_seg:=to_char(to_date(p_work_permit_expiry_date,'DD-MON-YY'),'yyyy/mm/dd')||'00:00:00';
                 END IF;


      IF    NVL (r_pre_per_extra_info.pei_information1, '0')                       <>   NVL(p_work_permit_number,'0') OR
             NVL (r_pre_per_extra_info.pei_information2, '31-DEC-4712') <>  NVL(p_work_permit_expiry_date, '31-DEC-4712')
      THEN
         DBMS_OUTPUT.PUT_LINE ('Permit Changed.');
         DBMS_OUTPUT.PUT_LINE ('ObjectVN:'
                               || r_pre_per_extra_info.object_version_number
                              );
      ELSE

         DBMS_OUTPUT.PUT_LINE ('Permit Detail Not Changed.');
         RETURN;

      END IF;


      BEGIN

                 o_person_extra_info_id  := r_pre_per_extra_info.person_extra_info_id;
                 o_object_version_number := r_pre_per_extra_info.object_version_number;

if r_pre_per_extra_info.person_extra_info_id is not null
then
                 hr_person_extra_info_api.update_person_extra_info
                                (p_validate                          => FALSE,
                                 p_person_extra_info_id              => o_person_extra_info_id,
                                 -- In / Out
                                 p_object_version_number             => o_object_version_number,
                                 -- In
                                 p_pei_information_category          => 'GRC_WORK_PERMITS',
                                 p_pei_information1                  => p_work_permit_number,
                                 p_pei_information2                  => p_work_permi_date_seg--to_char(TO_DATE(p_work_permit_expiry_date,'DD-MON-YY'),'yyyy/mm/dd')||'00:00:00'
                                );

        else

        create_work_permit_details( p_person_id              => p_person_id,
                                          p_work_permit_number         => p_work_permit_number,
                                          p_work_permit_expiry_date    => p_work_permit_expiry_date
                                            );

        end if;

      EXCEPTION
       WHEN OTHERS THEN
                  g_error_message := 'Error in extra info API:' || SQLERRM;
                  fnd_file.put_line(fnd_file.log,'ERROR while Updating Work Permit details');
                  Fnd_File.put_line(Fnd_File.LOG, 'Error at SIT: '||DBMS_UTILITY.FORMAT_ERROR_STACK );
                  g_label2 := 'Person_id';
                  g_secondary_column := p_person_id ;
                  RAISE skip_record;
       END;


   EXCEPTION
      WHEN NO_DATA_FOUND
      THEN
              create_work_permit_details( p_person_id              => p_person_id,
                                          p_work_permit_number         => p_work_permit_number,
                                          p_work_permit_expiry_date    => p_work_permit_expiry_date
                                            );
      WHEN OTHERS
      THEN
         g_error_message    := 'Other Error at update_work_permit_details: ' || SQLERRM;
         Fnd_File.put_line(Fnd_File.LOG, 'Error at SIT: '||DBMS_UTILITY.FORMAT_ERROR_STACK );
                  g_label2 := 'Person_id';
                  g_secondary_column := p_person_id ;
         RAISE skip_record;
   END;

   /******************************************************************

   Procedure Create Greek Employee Start time
    -- Author: Rajesh Koneru
    -- Date:  Feb 12,2021
    -- Parameters:
    -- Description: This procedure creates Greece Employee Start Time
    -- Modification Log
    -- Version    Developer              Date         Description
    -- ---        ----------------    -----------     --------------------------------
    -- 1.0        Rajesh Koneru       Feb 12,2021     Create Employee Start Time
    --

*********************************************************************/

    PROCEDURE create_grc_starttime(
                                p_business_group_id  IN  NUMBER,
                                p_person_id          IN  NUMBER,
                                p_effective_date     IN  DATE,
                                p_segment_1          IN  VARCHAR2
                              ) IS


    v_analysis_criteria_id      per_person_analyses.analysis_criteria_id%TYPE;
    v_person_analysis_id        per_person_analyses.person_analysis_id%TYPE;
    v_pea_object_version_number per_person_analyses.object_version_number%TYPE;
    v_id_flex   fnd_id_flex_structures_vl.id_flex_num%TYPE;

    l_success_flag              g_success_flag%TYPE;
    l_error_message             g_error_message%TYPE;
    l_segment1                  per_analysis_criteria.segment1%TYPE;



    CURSOR c_id_flex IS
    SELECT id_flex_num
    FROM fnd_id_flex_structures_vl
    WHERE  ID_FLEX_STRUCTURE_CODE = 'GRC_EMPLOYEE_START_TIME';

   BEGIN
      g_module_name := 'GRC_EMPLOYEE_START_TIME';

       OPEN c_id_flex;
       FETCH c_id_flex INTO v_id_flex;
       CLOSE c_id_flex;

        hr_sit_api.create_sit
            (p_person_id                  =>  p_person_id,
             p_business_group_id          =>  p_business_group_id,
             p_id_flex_num                =>  v_id_flex,
             p_effective_date             =>  p_effective_date,
             p_date_from                  =>  p_effective_date,
             p_segment1                   =>  p_segment_1,
             p_analysis_criteria_id       =>  v_analysis_criteria_id,
             p_person_analysis_id         =>  v_person_analysis_id,
             p_pea_object_version_number  =>  v_pea_object_version_number);

            l_success_flag := 'Y';

    EXCEPTION
    WHEN OTHERS
    THEN
        l_success_flag      := 'N';
        l_error_message     := SQLERRM;
        g_error_message     := 'Error others in Create Greece Start time' || SQLERRM;
        g_label2            := 'Person Id';
        g_secondary_column  := p_person_id;
        RAISE skip_record;
   END  create_grc_starttime;

   /*************************************************************************************************************
    -- PROCEDURE create_greek_work_info
    -- Author: Rajesh Koneru
    -- Date:  Feb 12, 2021
    -- Parameters:
    -- Description: This procedure creates Greek Work information.
    **************************************************************************************************************/
   PROCEDURE  create_greek_work_info( p_person_id              IN   NUMBER,
                                        p_work_on_holidays     IN  NUMBER,
                                        p_work_days_week     IN  NUMBER
                                   )
   IS
      o_object_version_number   per_people_extra_info.object_version_number%TYPE;
      o_person_extra_info_id    per_people_extra_info.person_extra_info_id%TYPE;

   BEGIN

   g_module_name := 'cr_greek_work_info';

      BEGIN

                 o_person_extra_info_id  := NULL;
                 o_object_version_number := NULL;

                 hr_person_extra_info_api.create_person_extra_info
                                (p_validate                          => FALSE,
                                 p_person_id                         => p_person_id,
                                 p_information_type                  => 'GRC_WORK_INFORMATION',
                                 p_pei_information_category          => 'GRC_WORK_INFORMATION',
                                 p_pei_information1                  => p_work_on_holidays,
                                 p_pei_information2                  => p_work_days_week,
                                 --OUT Parameters
                                 p_person_extra_info_id              => o_person_extra_info_id ,
                                 p_object_version_number             => o_object_version_number
                                );

      EXCEPTION
       WHEN OTHERS THEN
                  g_error_message := 'Error in extra info API:' || SQLERRM;
                  fnd_file.put_line(fnd_file.log,'ERROR while creating greek work information details');
                  g_label2 := 'Person_id';
                  g_secondary_column := p_person_id ;
                  RAISE skip_record;
       END;
  END create_greek_work_info;

   /******************************************************************

   Procedure Create Greek Contract END Date
    -- Author: Rajesh Koneru
    -- Date:  Feb 12,2021
    -- Parameters:
    -- Description: This procedure creates Greece Employee Contract End Date
    -- Modification Log
    -- Version    Developer              Date         Description
    -- ---        ----------------    -----------     --------------------------------
    -- 1.0        Rajesh Koneru       Feb 12,2021     Create Employee Contract End Date
    --

*********************************************************************/

    PROCEDURE create_grc_contract_end_date(
                                p_business_group_id  IN  NUMBER,
                                p_person_id          IN  NUMBER,
                                p_effective_date     IN  DATE,
                                p_segment_1          IN  VARCHAR2
                              ) IS


    v_analysis_criteria_id      per_person_analyses.analysis_criteria_id%TYPE;
    v_person_analysis_id        per_person_analyses.person_analysis_id%TYPE;
    v_pea_object_version_number per_person_analyses.object_version_number%TYPE;
    v_id_flex   fnd_id_flex_structures_vl.id_flex_num%TYPE;

    l_success_flag              g_success_flag%TYPE;
    l_error_message             g_error_message%TYPE;
    l_segment1                  per_analysis_criteria.segment1%TYPE;



    CURSOR c_id_flex IS
    SELECT id_flex_num
    FROM fnd_id_flex_structures_vl
    WHERE  ID_FLEX_STRUCTURE_CODE = 'GRC_CONTRACT_END_DATE';

   BEGIN
      g_module_name := 'GRC_CONTRACT_END_DATE';

       OPEN c_id_flex;
       FETCH c_id_flex INTO v_id_flex;
       CLOSE c_id_flex;

        hr_sit_api.create_sit
            (p_person_id                  =>  p_person_id,
             p_business_group_id          =>  p_business_group_id,
             p_id_flex_num                =>  v_id_flex,
             p_effective_date             =>  p_effective_date,
             p_date_from                  =>  p_effective_date,
             p_segment1                   =>  p_segment_1,  -- Please check in converting to date format, as we are using value set FND_STANDARD_DATE
             p_analysis_criteria_id       =>  v_analysis_criteria_id,
             p_person_analysis_id         =>  v_person_analysis_id,
             p_pea_object_version_number  =>  v_pea_object_version_number);

            l_success_flag := 'Y';

    EXCEPTION
    WHEN OTHERS
    THEN
        l_success_flag      := 'N';
        l_error_message     := SQLERRM;
        g_error_message     := 'Error others in Create Greece Contract END Date' || SQLERRM;
        g_label2            := 'Person Id';
        g_secondary_column  := p_person_id;
        RAISE skip_record;
   END  create_grc_contract_end_date;


    /*************************************************************************************************************
    -- PROCEDURE create_greek_att_mode
    -- Author: Rajesh Koneru
    -- Date:  Feb 12, 2021
    -- Parameters:
    -- Description: This procedure creates Greek First Name and Last Name
    **************************************************************************************************************/
   PROCEDURE  create_greek_att_mode( p_person_id              IN   NUMBER,
                                          p_greek_att_mode     IN  NUMBER
                                   )
   IS
      o_object_version_number   per_people_extra_info.object_version_number%TYPE;
      o_person_extra_info_id    per_people_extra_info.person_extra_info_id%TYPE;

   BEGIN

   g_module_name := 'cr_greek_attendance_mode';

      BEGIN

                 o_person_extra_info_id  := NULL;
                 o_object_version_number := NULL;

                 hr_person_extra_info_api.create_person_extra_info
                                (p_validate                          => FALSE,
                                 p_person_id                         => p_person_id,
                                 p_information_type                  => 'GRC_ATTENDANCE_MODE',
                                 p_pei_information_category          => 'GRC_ATTENDANCE_MODE',
                                 p_pei_information1                  => p_greek_att_mode,
                                 --OUT Parameters
                                 p_person_extra_info_id              => o_person_extra_info_id ,
                                 p_object_version_number             => o_object_version_number
                                );

      EXCEPTION
       WHEN OTHERS THEN
                  g_error_message := 'Error in extra info API:' || SQLERRM;
                  fnd_file.put_line(fnd_file.log,'ERROR while creating greek Attendance Mode details');
                  g_label2 := 'Person_id';
                  g_secondary_column := p_person_id ;
                  RAISE skip_record;
       END;
  END create_greek_att_mode;


    /*************************************************************************************************************
    -- PROCEDURE create_greek_name
    -- Author: Rajesh Koneru
    -- Date:  Feb 12, 2021
    -- Parameters:
    -- Description: This procedure creates Greek First Name and Last Name
    **************************************************************************************************************/
   PROCEDURE  create_greek_name( p_person_id              IN   NUMBER,
                                          p_greek_fn     IN   VARCHAR2,
                                          p_greek_ln       IN   VARCHAR2
                                   )
   IS
      o_object_version_number   per_people_extra_info.object_version_number%TYPE;
      o_person_extra_info_id    per_people_extra_info.person_extra_info_id%TYPE;

   BEGIN

   g_module_name := 'cr_greek_first_and_last_names';

      BEGIN

                 o_person_extra_info_id  := NULL;
                 o_object_version_number := NULL;

                 hr_person_extra_info_api.create_person_extra_info
                                (p_validate                          => FALSE,
                                 p_person_id                         => p_person_id,
                                 p_information_type                  => 'GRC_EMP_GREEK_NAMES',
                                 p_pei_information_category          => 'GRC_EMP_GREEK_NAMES',
                                 p_pei_information1                  => p_greek_fn,
                                 p_pei_information2                  => p_greek_ln,
                                 --OUT Parameters
                                 p_person_extra_info_id              => o_person_extra_info_id ,
                                 p_object_version_number             => o_object_version_number
                                );

      EXCEPTION
       WHEN OTHERS THEN
                  g_error_message := 'Error in extra info API:' || SQLERRM;
                  fnd_file.put_line(fnd_file.log,'ERROR while creating greek Name details');
                  g_label2 := 'Person_id';
                  g_secondary_column := p_person_id ;
                  RAISE skip_record;
       END;
  END create_greek_name;

  /*************************************************************************************************************
    -- PROCEDURE update_grc_Greek_Name_details
    -- Author: Rajesh Koneru
    -- Date:  Feb 12, 2020
    -- Parameters:
    -- Description: This procedure updates Greece employee First name and Last name details if changed in greek language
    **************************************************************************************************************/
   PROCEDURE  update_greek_name( p_person_id              IN   NUMBER,
                                        p_greek_fn     IN   VARCHAR2,
                                          p_greek_ln       IN   VARCHAR2)
   IS
      o_object_version_number   per_people_extra_info.object_version_number%TYPE;
      o_person_extra_info_id    per_people_extra_info.person_extra_info_id%TYPE;

      CURSOR c_pre_per_extra_info
      IS
         SELECT *
           FROM   APPS.PER_PEOPLE_EXTRA_INFO
          WHERE person_id = p_person_id
            AND information_type = 'GRC_EMP_GREEK_NAMES'
            AND pei_information_category = 'GRC_EMP_GREEK_NAMES'
            AND rownum < 2
           ORDER BY object_version_number desc;

      r_pre_per_extra_info       c_pre_per_extra_info%ROWTYPE;

   BEGIN
      g_module_name := 'upd_greek_first_and_last_names';
      Fnd_File.put_line(Fnd_File.LOG, 'Before opening cursor');
      OPEN c_pre_per_extra_info;

      FETCH c_pre_per_extra_info
       INTO r_pre_per_extra_info;

      CLOSE c_pre_per_extra_info;
      Fnd_File.put_line(Fnd_File.LOG, 'After Closing the cursor');

      IF    NVL (r_pre_per_extra_info.pei_information1, 'XXX')     <>  NVL(p_greek_fn,'XXX') OR
            NVL (r_pre_per_extra_info.pei_information2, 'XXX') <>  NVL(p_greek_ln, 'XXX')
      THEN
         DBMS_OUTPUT.PUT_LINE ('Greek First name and last name Detail Changed.');
         Fnd_File.put_line(Fnd_File.LOG, 'Greek First and Last name changed.');
         DBMS_OUTPUT.PUT_LINE ('ObjectVN:'
                               || r_pre_per_extra_info.object_version_number
                              );
      ELSE
         Fnd_File.put_line(Fnd_File.LOG, 'Greek Name Detail Not Changed.');
         DBMS_OUTPUT.PUT_LINE ('Greek Name Detail Not Changed.');
         RETURN;

      END IF;


      BEGIN

                 o_person_extra_info_id  := r_pre_per_extra_info.person_extra_info_id;
                 o_object_version_number := r_pre_per_extra_info.object_version_number;

                  Fnd_File.put_line(Fnd_File.LOG, 'Checking o_person_extra_info_id:'||o_person_extra_info_id);
                   Fnd_File.put_line(Fnd_File.LOG, 'Checking o_object_version_number:'||o_object_version_number );
      if r_pre_per_extra_info.person_extra_info_id is not null
      then
                 hr_person_extra_info_api.update_person_extra_info
                                (p_validate                          => FALSE,
                                 p_person_extra_info_id              => o_person_extra_info_id,
                                 -- In / Out
                                 p_object_version_number             => o_object_version_number,
                                 -- In
                                 p_pei_information_category          => 'GRC_EMP_GREEK_NAMES',
                                 p_pei_information1                  => p_greek_fn,
                                 p_pei_information2                  => p_greek_ln
                                );
          else

          create_greek_name( p_person_id  => p_person_id,
                                          p_greek_fn     => p_greek_fn,
                                          p_greek_ln     => p_greek_ln
										  );

          end if;


      EXCEPTION
       WHEN OTHERS THEN
                  g_error_message := 'Error in extra info API:' || SQLERRM;
                  fnd_file.put_line(fnd_file.log,'ERROR while Updating Greek First name and last details');
                  g_label2 := 'Person_id';
                  g_secondary_column := p_person_id ;
                  RAISE skip_record;
       END;


   EXCEPTION
      WHEN NO_DATA_FOUND
      THEN
                       create_greek_name( p_person_id  => p_person_id,
                                          p_greek_fn     => p_greek_fn,
                                          p_greek_ln     => p_greek_ln
										  );
      WHEN OTHERS
      THEN


          Fnd_File.put_line(Fnd_File.LOG, 'Error information:'||DBMS_UTILITY.FORMAT_ERROR_STACK );
         g_error_message    := 'Other Error at upd_greek_first_and_last_names: ' || SQLERRM;
                  g_label2 := 'Person_id';
                  g_secondary_column := p_person_id ;
         RAISE skip_record;
   END;

  /*************************************************************************************************************
    -- PROCEDURE upd_greek_attendance_mode
    -- Author: Rajesh Koneru
    -- Date:  Feb 12, 2020
    -- Parameters:
    -- Description: This procedure updates Greece employee Attendance mode details
    **************************************************************************************************************/
   PROCEDURE  update_greek_att_mode( p_person_id              IN   NUMBER,
                                     p_greek_att_mode     IN   NUMBER
										)
   IS
      o_object_version_number   per_people_extra_info.object_version_number%TYPE;
      o_person_extra_info_id    per_people_extra_info.person_extra_info_id%TYPE;

      CURSOR c_pre_per_extra_info
      IS
         SELECT *
           FROM   APPS.PER_PEOPLE_EXTRA_INFO
          WHERE person_id = p_person_id
            AND information_type = 'GRC_ATTENDANCE_MODE'
            AND pei_information_category = 'GRC_ATTENDANCE_MODE'
            AND rownum < 2
           ORDER BY object_version_number desc;

      r_pre_per_extra_info       c_pre_per_extra_info%ROWTYPE;

   BEGIN
      g_module_name := 'upd_greek_attendance_mode';
      Fnd_File.put_line(Fnd_File.LOG, 'Before opening cursor');
      OPEN c_pre_per_extra_info;

      FETCH c_pre_per_extra_info
       INTO r_pre_per_extra_info;

      CLOSE c_pre_per_extra_info;
      Fnd_File.put_line(Fnd_File.LOG, 'After Closing the cursor');

      IF    NVL (r_pre_per_extra_info.pei_information1, 0)     <>  NVL(p_greek_att_mode,0)
      THEN
         DBMS_OUTPUT.PUT_LINE ('Greek Attendance Detail Changed.');
         Fnd_File.put_line(Fnd_File.LOG, 'Greek Attendance Detail Changed.');
         DBMS_OUTPUT.PUT_LINE ('ObjectVN:'
                               || r_pre_per_extra_info.object_version_number
                              );
      ELSE
         Fnd_File.put_line(Fnd_File.LOG, 'Greek Attendance Details Not Changed.');
         DBMS_OUTPUT.PUT_LINE ('Greek Attendance Details Not Changed.');
         RETURN;

      END IF;


      BEGIN

                 o_person_extra_info_id  := r_pre_per_extra_info.person_extra_info_id;
                 o_object_version_number := r_pre_per_extra_info.object_version_number;

                   Fnd_File.put_line(Fnd_File.LOG, 'Checking o_person_extra_info_id:'||o_person_extra_info_id);
                   Fnd_File.put_line(Fnd_File.LOG, 'Checking o_object_version_number:'||o_object_version_number );
      if r_pre_per_extra_info.person_extra_info_id is not null
      then
                 hr_person_extra_info_api.update_person_extra_info
                                (p_validate                          => FALSE,
                                 p_person_extra_info_id              => o_person_extra_info_id,
                                 -- In / Out
                                 p_object_version_number             => o_object_version_number,
                                 -- In
                                 p_pei_information_category          => 'GRC_ATTENDANCE_MODE',
                                 p_pei_information1                  => p_greek_att_mode
                                );
          else

          create_greek_att_mode( p_person_id  => p_person_id,
                                          p_greek_att_mode  => p_greek_att_mode
										  );

          end if;


      EXCEPTION
       WHEN OTHERS THEN
                  g_error_message := 'Error in extra info API:' || SQLERRM;
                  fnd_file.put_line(fnd_file.log,'ERROR while Updating Greek Attendance Mode details');
                  g_label2 := 'Person_id';
                  g_secondary_column := p_person_id ;
                  RAISE skip_record;
       END;


   EXCEPTION
      WHEN NO_DATA_FOUND
      THEN
                                 create_greek_att_mode( p_person_id  => p_person_id,
                                          p_greek_att_mode  => p_greek_att_mode
										  );
      WHEN OTHERS
      THEN


          Fnd_File.put_line(Fnd_File.LOG, 'Error information:'||DBMS_UTILITY.FORMAT_ERROR_STACK );
         g_error_message    := 'Other Error at upd_greek_attendance_mode: ' || SQLERRM;
                  g_label2 := 'Person_id';
                  g_secondary_column := p_person_id ;
         RAISE skip_record;
   END;

   /*************************************************************************************************************
    -- PROCEDURE upd_greek_work_info
    -- Author: Rajesh Koneru
    -- Date:  Feb 12, 2020
    -- Parameters:
    -- Description: This procedure updates Greece employee work Information
    **************************************************************************************************************/
   PROCEDURE  update_greek_work_info( p_person_id              IN   NUMBER,
                                     p_work_on_holidays     IN  NUMBER,
                                     p_work_days_week       IN  NUMBER
										)
   IS
      o_object_version_number   per_people_extra_info.object_version_number%TYPE;
      o_person_extra_info_id    per_people_extra_info.person_extra_info_id%TYPE;

      CURSOR c_pre_per_extra_info
      IS
         SELECT *
           FROM   APPS.PER_PEOPLE_EXTRA_INFO
          WHERE person_id = p_person_id
            AND information_type = 'GRC_WORK_INFORMATION'
            AND pei_information_category = 'GRC_WORK_INFORMATION'
            AND rownum < 2
           ORDER BY object_version_number desc;

      r_pre_per_extra_info       c_pre_per_extra_info%ROWTYPE;

   BEGIN
      g_module_name := 'upd_greek_work_info';
      Fnd_File.put_line(Fnd_File.LOG, 'Before opening cursor');
      OPEN c_pre_per_extra_info;

      FETCH c_pre_per_extra_info
       INTO r_pre_per_extra_info;

      CLOSE c_pre_per_extra_info;
      Fnd_File.put_line(Fnd_File.LOG, 'After Closing the cursor');

      IF    NVL (r_pre_per_extra_info.pei_information1, 0)     <>  NVL(p_work_on_holidays,0) OR
	        NVL (r_pre_per_extra_info.pei_information1, 0)     <>  NVL(p_work_days_week,0)
      THEN
         DBMS_OUTPUT.PUT_LINE ('Greek work information Detail Changed.');
         Fnd_File.put_line(Fnd_File.LOG, 'Greek work information Detail Changed.');
         DBMS_OUTPUT.PUT_LINE ('ObjectVN:'
                               || r_pre_per_extra_info.object_version_number
                              );
      ELSE
         Fnd_File.put_line(Fnd_File.LOG, 'Greek Work Information Details Not Changed.');
         DBMS_OUTPUT.PUT_LINE ('Greek Work Information Details Not Changed.');
         RETURN;

      END IF;


      BEGIN

                 o_person_extra_info_id  := r_pre_per_extra_info.person_extra_info_id;
                 o_object_version_number := r_pre_per_extra_info.object_version_number;

                   Fnd_File.put_line(Fnd_File.LOG, 'Checking o_person_extra_info_id:'||o_person_extra_info_id);
                   Fnd_File.put_line(Fnd_File.LOG, 'Checking o_object_version_number:'||o_object_version_number );
      if r_pre_per_extra_info.person_extra_info_id is not null
      then
                 hr_person_extra_info_api.update_person_extra_info
                                (p_validate                          => FALSE,
                                 p_person_extra_info_id              => o_person_extra_info_id,
                                 -- In / Out
                                 p_object_version_number             => o_object_version_number,
                                 -- In
                                 p_pei_information_category          => 'GRC_WORK_INFORMATION',
                                 p_pei_information1                  => p_work_on_holidays,
								 p_pei_information2                  => p_work_days_week
                                );
          else

          create_greek_work_info( p_person_id  => p_person_id,
                                   p_work_on_holidays                  => p_work_on_holidays,
								 p_work_days_week                  => p_work_days_week
										  );
          end if;


      EXCEPTION
       WHEN OTHERS THEN
                  g_error_message := 'Error in extra info API:' || SQLERRM;
                  fnd_file.put_line(fnd_file.log,'ERROR while Updating Greek Work Information details');
                  g_label2 := 'Person_id';
                  g_secondary_column := p_person_id ;
                  RAISE skip_record;
       END;


   EXCEPTION
      WHEN NO_DATA_FOUND
      THEN
                                create_greek_work_info( p_person_id  => p_person_id,
                                   p_work_on_holidays                  => p_work_on_holidays,
								 p_work_days_week                  => p_work_days_week
										  );
      WHEN OTHERS
      THEN


          Fnd_File.put_line(Fnd_File.LOG, 'Error information:'||DBMS_UTILITY.FORMAT_ERROR_STACK );
         g_error_message    := 'Other Error at upd_greek_work_info: ' || SQLERRM;
                  g_label2 := 'Person_id';
                  g_secondary_column := p_person_id ;
         RAISE skip_record;
   END;

   /******************************************************************

   Procedure update_grc_starttime
    -- Author: Rajesh Koneru
    -- Date:  Feb 12,2020

*********************************************************************/
   PROCEDURE update_grc_starttime (      p_business_group_id  IN  NUMBER,
                                p_person_id          IN  NUMBER,
                                p_employee_number    IN  VARCHAR2,
                                p_effective_date     IN  DATE,
                                p_segment_1          IN  VARCHAR2
                                      )
   IS
      l_success_flag    g_success_flag%TYPE;
      l_error_message   g_error_message%TYPE;

      v_date_to             date;
      v_previous_date_from         date;

      v_pea_object_version_number     NUMBER;
      v_id_flex_num                   fnd_id_flex_structures_vl.id_flex_num%TYPE;
      v_person_analysis_id            per_person_analyses.person_analysis_id%TYPE;
      v_analysis_criteria_id          per_analysis_criteria.analysis_criteria_id%TYPE;

      CURSOR c_id_flex IS
      SELECT id_flex_num
      FROM fnd_id_flex_structures_vl
      WHERE  ID_FLEX_STRUCTURE_CODE = 'GRC_EMPLOYEE_START_TIME';


      CURSOR c_pre_contract IS
        SELECT  pa.person_analysis_id
                ,ac.ANALYSIS_CRITERIA_ID ,pa.date_from
                ,pa.object_version_number
		--START R12.2 Upgrade Remediation		
          /*FROM  hr.per_person_analyses pa,			-- Commented code by IXPRAVEEN-ARGANO,14-july-2023
                hr.per_analysis_criteria ac*/
		  FROM  apps.per_person_analyses pa,		--  code Added by IXPRAVEEN-ARGANO,   14-july-2023
                apps.per_analysis_criteria ac		
				--END R12.2.12 Upgrade remediation
         WHERE pa.analysis_criteria_id = ac.analysis_criteria_id
           AND pa.id_flex_num = v_id_flex_num
           AND pa.person_id = p_person_id
           AND date_from = (SELECT MAX(pa1.date_from)
                            --FROM  hr.per_person_analyses pa1		-- Commented code by IXPRAVEEN-ARGANO,14-july-2023
                            FROM  apps.per_person_analyses pa1      --  code Added by IXPRAVEEN-ARGANO,   14-july-2023
                            where pa1.id_flex_num = v_id_flex_num
                            AND pa1.person_id = p_person_id);

   BEGIN
      g_module_name := 'update_grc_starttime';

       OPEN c_id_flex;
       FETCH c_id_flex INTO v_id_flex_num;
       CLOSE c_id_flex;

       OPEN c_pre_contract;
       FETCH c_pre_contract INTO v_person_analysis_id,v_analysis_criteria_id,v_previous_date_from
             ,v_pea_object_version_number;
       CLOSE c_pre_contract;


      IF v_person_analysis_id IS NOT NULL THEN


          v_date_to := p_effective_date - 1;

          IF v_previous_date_from >= v_date_to THEN

              /* FORCED TO End date the existing record with the day before current effective date*/

              hr_sit_api.update_sit
                        (p_validate                     => FALSE
                        ,p_person_analysis_id           => v_person_analysis_id
                        ,p_pea_object_version_number    => v_pea_object_version_number
                        ,p_analysis_criteria_id         => v_analysis_criteria_id
                        ,p_date_from                    => v_date_to
                        ,p_date_to                      => v_date_to
                        );


          ELSE

               /* End date the existing record */
               hr_sit_api.update_sit
                            (p_validate                     => FALSE
                            ,p_person_analysis_id           => v_person_analysis_id
                            ,p_pea_object_version_number    => v_pea_object_version_number
                            ,p_analysis_criteria_id         => v_analysis_criteria_id
                            ,p_date_to                      => v_date_to
                            );
          END IF;

      END IF;

        /* Rehire - Create hireIQ' */

        v_analysis_criteria_id := NULL;

        hr_sit_api.create_sit
            (p_person_id                  =>  p_person_id,
             p_business_group_id          =>  p_business_group_id,
             p_id_flex_num                =>  v_id_flex_num,
             p_effective_date             =>  p_effective_date,
             p_date_from                  =>  p_effective_date,
             p_segment1                   =>  p_segment_1,
             p_analysis_criteria_id       =>  v_analysis_criteria_id,
             p_person_analysis_id         =>  v_person_analysis_id,
             p_pea_object_version_number  =>  v_pea_object_version_number);

   EXCEPTION
      WHEN api_error
      THEN
         g_error_message    := 'API Error in  Update Start time' || l_error_message;
         g_label2           := 'Greek Start Time';
         g_secondary_column := p_employee_number;
         RAISE skip_record;
      WHEN OTHERS
      THEN
         g_error_message    := 'Other Error in  Update Start time' || SQLERRM;
         g_label2           := 'Greek Start Time';
         g_secondary_column := p_employee_number;
         RAISE skip_record;
   END update_grc_starttime;

   /******************************************************************

   Procedure update_grc_contract_end_date
    -- Author: Rajesh Koneru
    -- Date:  Feb 12,2020

*********************************************************************/
   PROCEDURE update_grc_contract_end_date (      p_business_group_id  IN  NUMBER,
                                p_person_id          IN  NUMBER,
                                p_employee_number    IN  VARCHAR2,
                                p_effective_date     IN  DATE,
                                p_segment_1          IN  VARCHAR2
                                      )
   IS
      l_success_flag    g_success_flag%TYPE;
      l_error_message   g_error_message%TYPE;

      v_date_to             date;
      v_previous_date_from         date;

      v_pea_object_version_number     NUMBER;
      v_id_flex_num                   fnd_id_flex_structures_vl.id_flex_num%TYPE;
      v_person_analysis_id            per_person_analyses.person_analysis_id%TYPE;
      v_analysis_criteria_id          per_analysis_criteria.analysis_criteria_id%TYPE;

      CURSOR c_id_flex IS
      SELECT id_flex_num
      FROM fnd_id_flex_structures_vl
      WHERE  ID_FLEX_STRUCTURE_CODE = 'GRC_CONTRACT_END_DATE';


      CURSOR c_pre_contract IS
        SELECT  pa.person_analysis_id
                ,ac.ANALYSIS_CRITERIA_ID ,pa.date_from
                ,pa.object_version_number
		  --START R12.2 Upgrade Remediation		
          /*FROM  hr.per_person_analyses pa,			-- Commented code by IXPRAVEEN-ARGANO,14-july-2023
                hr.per_analysis_criteria ac*/
		  FROM  apps.per_person_analyses pa,		--  code Added by IXPRAVEEN-ARGANO,   14-july-2023
                apps.per_analysis_criteria ac		
				--END R12.2.12 Upgrade remediation		
         WHERE pa.analysis_criteria_id = ac.analysis_criteria_id
           AND pa.id_flex_num = v_id_flex_num
           AND pa.person_id = p_person_id
           AND date_from = (SELECT MAX(pa1.date_from)
                            --FROM  hr.per_person_analyses pa1			-- Commented code by IXPRAVEEN-ARGANO,14-july-2023
                            FROM  APPS.per_person_analyses pa1          --  code Added by IXPRAVEEN-ARGANO,   14-july-2023
                            where pa1.id_flex_num = v_id_flex_num
                            AND pa1.person_id = p_person_id);

   BEGIN
      g_module_name := 'update_grc_contract_end_date';

       OPEN c_id_flex;
       FETCH c_id_flex INTO v_id_flex_num;
       CLOSE c_id_flex;

       OPEN c_pre_contract;
       FETCH c_pre_contract INTO v_person_analysis_id,v_analysis_criteria_id,v_previous_date_from
             ,v_pea_object_version_number;
       CLOSE c_pre_contract;


      IF v_person_analysis_id IS NOT NULL THEN


          v_date_to := p_effective_date - 1;

          IF v_previous_date_from >= v_date_to THEN

              /* FORCED TO End date the existing record with the day before current effective date*/

              hr_sit_api.update_sit
                        (p_validate                     => FALSE
                        ,p_person_analysis_id           => v_person_analysis_id
                        ,p_pea_object_version_number    => v_pea_object_version_number
                        ,p_analysis_criteria_id         => v_analysis_criteria_id
                        ,p_date_from                    => v_date_to
                        ,p_date_to                      => v_date_to
                        );


          ELSE

               /* End date the existing record */
               hr_sit_api.update_sit
                            (p_validate                     => FALSE
                            ,p_person_analysis_id           => v_person_analysis_id
                            ,p_pea_object_version_number    => v_pea_object_version_number
                            ,p_analysis_criteria_id         => v_analysis_criteria_id
                            ,p_date_to                      => v_date_to
                            );
          END IF;

      END IF;
    /* Rehire - Create hireIQ' */

        v_analysis_criteria_id := NULL;

        hr_sit_api.create_sit
            (p_person_id                  =>  p_person_id,
             p_business_group_id          =>  p_business_group_id,
             p_id_flex_num                =>  v_id_flex_num,
             p_effective_date             =>  p_effective_date,
             p_date_from                  =>  p_effective_date,
             p_segment1                   =>  p_segment_1,
             p_analysis_criteria_id       =>  v_analysis_criteria_id,
             p_person_analysis_id         =>  v_person_analysis_id,
             p_pea_object_version_number  =>  v_pea_object_version_number);

   EXCEPTION
      WHEN api_error
      THEN
         g_error_message    := 'API Error in updating Contract End date' || l_error_message;
         g_label2           := 'Greek Contract End Date';
         g_secondary_column := p_employee_number;
         RAISE skip_record;
      WHEN OTHERS
      THEN
         g_error_message    := 'Other Error in updating Contract End date' || SQLERRM;
         g_label2           := 'Greek Contract End Date';
         g_secondary_column := p_employee_number;
         RAISE skip_record;
   END update_grc_contract_end_date;

/* 7.3.3 End */
/* 7.3.4 Begin */
    /*************************************************************************************************************
    -- PROCEDURE create_passport_details
    -- Author: Christiane
    -- Date:  Nov 12, 2020
    -- Parameters:
    -- Description: This procedure creates Passport Details specifically for candidate from business group who are required to report
    --                        passport info.
    **************************************************************************************************************/
   PROCEDURE  create_passport_details( p_person_id              IN   NUMBER,
                                          p_passport_number         IN   VARCHAR2,
                                          p_passport_expiry_date    IN   VARCHAR2)
   IS
      o_object_version_number   per_people_extra_info.object_version_number%TYPE;
      o_person_extra_info_id    per_people_extra_info.person_extra_info_id%TYPE;
      l_passport_date_seg	varchar2(100):=NULL;

   BEGIN
      g_module_name := 'create_passport';
      BEGIN
                 o_person_extra_info_id  := NULL;
                 o_object_version_number := NULL;

                 IF p_passport_expiry_date IS NULL
                 THEN
                 l_passport_date_seg:=null;
                 ELSE
                 l_passport_date_seg:=to_char(to_date(p_passport_expiry_date,'DD-MON-YY'),'yyyy/mm/dd')||'00:00:00';
                 END IF;

                 hr_person_extra_info_api.create_person_extra_info
                                (p_validate                          => FALSE,
                                 p_person_id                         => p_person_id,
                                 p_information_type                  => 'GRC_PASSPORT_DETAILS',
                                 p_pei_information_category          => 'GRC_PASSPORT_DETAILS',
                                 p_pei_information1                  => p_passport_number,
                                 p_pei_information2                  => l_passport_date_seg,
                                 --OUT Parameters
                                 p_person_extra_info_id              => o_person_extra_info_id ,
                                 p_object_version_number             => o_object_version_number
                                );

      EXCEPTION
       WHEN OTHERS THEN
                  g_error_message := 'Error in extra info API:' || SQLERRM;
                  fnd_file.put_line(fnd_file.log,'ERROR while Creating Passport details');
                  g_label2 := 'Person_id';
                  g_secondary_column := p_person_id ;
                  RAISE skip_record;
       END;
  END create_passport_details;
    /*************************************************************************************************************
    -- PROCEDURE update_passport_details
    -- Author: Christiane Chan
    -- Date:  Nov 12, 2020
    -- Parameters:
    -- Description: This procedure updates employee Passport details if changed.
    **************************************************************************************************************/
   PROCEDURE  update_passport_details( p_person_id              IN   NUMBER,
                                           p_passport_number        IN   VARCHAR2,
                                           p_passport_expiry_date   IN   VARCHAR2)
   IS
      o_object_version_number   per_people_extra_info.object_version_number%TYPE;
      o_person_extra_info_id    per_people_extra_info.person_extra_info_id%TYPE;
      l_passport_date_seg	varchar2(100):=NULL;

      CURSOR c_pre_per_extra_info
      IS
         SELECT *
           FROM   APPS.PER_PEOPLE_EXTRA_INFO
          WHERE person_id = p_person_id
            AND information_type = 'GRC_PASSPORT_DETAILS'
            AND pei_information_category = 'GRC_PASSPORT_DETAILS'
            AND rownum < 2
           ORDER BY object_version_number desc;

      r_pre_per_extra_info       c_pre_per_extra_info%ROWTYPE;

   BEGIN
      g_module_name := 'upd_passport_det';

      OPEN c_pre_per_extra_info;

      FETCH c_pre_per_extra_info
       INTO r_pre_per_extra_info;

      CLOSE c_pre_per_extra_info;

               IF p_passport_expiry_date IS NULL
                 THEN
                 l_passport_date_seg:=null;
                 ELSE
                 l_passport_date_seg:=to_char(to_date(p_passport_expiry_date,'DD-MON-YY'),'yyyy/mm/dd')||'00:00:00';
                 END IF;

      IF    NVL (r_pre_per_extra_info.pei_information1, '0')                       <>   NVL(p_passport_number,'0') OR
             NVL (r_pre_per_extra_info.pei_information2, '31-DEC-4712') <>  NVL(p_passport_expiry_date, '31-DEC-4712')
      THEN
         DBMS_OUTPUT.PUT_LINE ('Passport Detail Changed.');
         DBMS_OUTPUT.PUT_LINE ('ObjectVN:'
                               || r_pre_per_extra_info.object_version_number
                              );
      ELSE

         DBMS_OUTPUT.PUT_LINE ('Passport Detail Not Changed.');
         RETURN;

      END IF;


      BEGIN

                 o_person_extra_info_id  := r_pre_per_extra_info.person_extra_info_id;
                 o_object_version_number := r_pre_per_extra_info.object_version_number;

     if o_person_extra_info_id is not null
     then
                 hr_person_extra_info_api.update_person_extra_info
                                (p_validate                          => FALSE,
                                 p_person_extra_info_id              => o_person_extra_info_id,
                                 -- In / Out
                                 p_object_version_number             => o_object_version_number,
                                 -- In
                                 p_pei_information_category          => 'GRC_PASSPORT_DETAILS',
                                 p_pei_information1                  => p_passport_number,
                                 p_pei_information2                  => l_passport_date_seg--to_char(TO_DATE(p_passport_expiry_date,'DD-MON-YY'),'yyyy/mm/dd')||'00:00:00'
                                );
     else

      create_passport_details( p_person_id              => p_person_id,
                                          p_passport_number         => p_passport_number,
                                          p_passport_expiry_date    => p_passport_expiry_date
                                            );

     end if;

      EXCEPTION
       WHEN OTHERS THEN
                  g_error_message := 'Error in extra info API:' || SQLERRM;
                  fnd_file.put_line(fnd_file.log,'ERROR while Updating Passport details');
                  g_label2 := 'Person_id';
                  g_secondary_column := p_person_id ;
                  RAISE skip_record;
       END;


   EXCEPTION
      WHEN NO_DATA_FOUND
      THEN
              create_passport_details( p_person_id              => p_person_id,
                                          p_passport_number         => p_passport_number,
                                          p_passport_expiry_date    => p_passport_expiry_date
                                            );
      WHEN OTHERS
      THEN
         g_error_message    := 'Other Error at update_passport_details: ' || SQLERRM;
                  g_label2 := 'Person_id';
                  g_secondary_column := p_person_id ;
         RAISE skip_record;
   END;
/* 7.3.4 End */
/* 4.0.7 Begin */
    /*************************************************************************************************************
    -- PROCEDURE create_contact_relationship
    -- Author: Christiane
    -- Date:  Nov 17, 2017
    -- Parameters:
    -- Description: This procedure creates contact relationship record for the candidate.
    **************************************************************************************************************/
   PROCEDURE create_contact_relationship (
      p_start_date             IN   DATE,
      p_person_id              IN   NUMBER,
      p_business_group_id      IN   NUMBER,
      p_last_name              IN   VARCHAR2,
      p_sex                    IN   VARCHAR2,
      p_first_name             IN   VARCHAR2,
      p_middle_names           IN   VARCHAR2,
      p_contact_type           IN   VARCHAR2
   )
   IS
        ln_contact_rel_id                       PER_CONTACT_RELATIONSHIPS.CONTACT_RELATIONSHIP_ID%TYPE;
        ln_ctr_object_ver_num                   PER_CONTACT_RELATIONSHIPS.OBJECT_VERSION_NUMBER%TYPE;
        ln_contact_person                       PER_ALL_PEOPLE_F.PERSON_ID%TYPE;
        ln_object_version_number                PER_CONTACT_RELATIONSHIPS.OBJECT_VERSION_NUMBER%TYPE;
        ld_per_effective_start_date             DATE;
        ld_per_effective_end_date               DATE;
        lc_full_name                            PER_ALL_PEOPLE_F.FULL_NAME%TYPE;
        ln_per_comment_id                       PER_ALL_PEOPLE_F.COMMENT_ID%TYPE;
        lb_name_comb_warning                    BOOLEAN;
        lb_orig_hire_warning                    BOOLEAN;

        l_success_flag                          g_success_flag%TYPE;
        l_error_message                         g_error_message%TYPE;

   BEGIN
      g_module_name := 'create_contact_relationship';

      Fnd_File.put_line(Fnd_File.LOG, 'create_contact_relationship -  Calling hr_contact_rel_api.create_contact' );

    -- Create Employee Contact
    -- -------------------------------------
     hr_contact_rel_api.create_contact
     (    -- Input data elements
           -- -----------------------------
           p_validate                          => FALSE,
           p_start_date                        => p_start_date,
           p_business_group_id                 => p_business_group_id,
           p_person_id                         => p_person_id,
           p_contact_person_id                 => NULL,
           p_contact_type                      => p_contact_type,
           p_date_start                        => p_start_date,
           p_last_name                         => p_last_name,
           p_first_name                        => p_first_name,
           p_middle_names                      => p_middle_names,
           p_sex                               => p_sex,
            p_per_information1                 => 8, -- Mandatorty for Brazil have to default to 12 for undisclosed once fonfirmed with Shafi
        --    p_DATE_OF_BIRth                    => l_DATE_OF_BIRth, -- Will not be fed through Taleo
            p_attribute_category               => 1631, -- Mandatorty for Brazil
            p_attribute12                      => 'c',  -- Mandatorty for Brazil
           -- Output data elements
           -- --------------------------------
          p_contact_relationship_id            => ln_contact_rel_id,
          p_ctr_object_version_number      => ln_ctr_object_ver_num,
          p_per_person_id                              => ln_contact_person,
          p_per_object_version_number     => ln_object_version_number,
          p_per_effective_start_date             => ld_per_effective_start_date,
          p_per_effective_end_date              => ld_per_effective_end_date,
          p_full_name                                       => lc_full_name,
          p_per_comment_id                          => ln_per_comment_id,
          p_name_combination_warning  => lb_name_comb_warning,
          p_orig_hire_warning                      => lb_orig_hire_warning
     );

Fnd_File.put_line(Fnd_File.LOG, 'create_contact_relationship -  After Calling hr_contact_rel_api.create_contact ln_contact_rel_id ->' ||ln_contact_rel_id );
Fnd_File.put_line(Fnd_File.LOG, 'create_contact_relationship -  After Calling hr_contact_rel_api.create_contact      lc_full_name ->' || lc_full_name );

--      IF l_success_flag = 'N'
--      THEN

--         RAISE api_error;

--      END IF;

   EXCEPTION
      WHEN api_error
      THEN
         g_error_message    := 'Warning api contact relationship creation' || l_error_message;
         g_label2           := 'Contact type';
         g_secondary_column := p_contact_type;

         --cust.ttec_process_error (c_application_code,					-- Commented code by IXPRAVEEN-ARGANO,14-july-2023
         apps.ttec_process_error (c_application_code,                   --  code Added by IXPRAVEEN-ARGANO,   14-july-2023
                                  c_interface,
                                  c_program_name,
                                  g_module_name,
                                  c_warning_status,
                                  SQLCODE,
                                  g_error_message,
                                  g_label1,
                                  g_primary_column,
                                  g_label2,
                                  g_secondary_column
                                 );

         print_line (   RPAD (NVL (g_primary_column, ' '), 10)
                     || ' '
                     || RPAD (NVL (g_label2, ' '), 17)
                     || ' '
                     || RPAD (NVL (g_secondary_column, ' '), 16)
                     || ' '
                     || RPAD (NVL (g_error_message, ' '), 51)
                    );

      WHEN OTHERS
      THEN
         g_error_message    := 'Warning other contact relationship creation' || l_error_message;
         g_label2           := 'Contact type';
         g_secondary_column := p_contact_type;
         RAISE skip_record;
   END;

/* 4.0.7  End */
/* 4.0.7 Begin */
    /*************************************************************************************************************
    -- PROCEDURE update_contact_relationship
    -- Author: Christiane
    -- Date:  Nov 17, 2017
    -- Parameters:
    -- Description: This procedure updates the contact relationship record for the candidate.
    -- Modification Log

    -- Version    Developer              Date         Description
    -- ---        ----------------    -----------     --------------------------------
	--
    ****************************************************************************************************************************************************************************/
     PROCEDURE update_contact_relationship (
      p_start_date             IN   DATE,
      p_person_id              IN   NUMBER,
      p_business_group_id      IN   NUMBER,
      p_sex                    IN   VARCHAR2,
      p_last_name              IN   VARCHAR2,
      p_first_name             IN   VARCHAR2,
      p_middle_names           IN   VARCHAR2,
      p_contact_type           IN   VARCHAR2
       )
    IS

        l_success_flag                g_success_flag%TYPE;

        l_error_message               g_error_message%TYPE;
        l_attribute_category          per_all_people_f.attribute_category%TYPE;

        l_change                      VARCHAR2 (1);

        l_person_id                   per_all_people_f.person_id%TYPE;
        l_employee_number             per_all_people_f.employee_number%TYPE;
        l_per_object_version_number   per_all_people_f.object_version_number%TYPE;
        l_per_effective_start_date    per_all_people_f.effective_start_date%TYPE;
        l_per_effective_end_date      per_all_people_f.effective_end_date%TYPE;
        l_first_name                  per_all_people_f.first_name%TYPE;
        l_last_name                   per_all_people_f.last_name%TYPE;
        l_middle_names                per_all_people_f.middle_names%TYPE;
        l_full_name                   per_all_people_f.full_name%TYPE;
        l_sex                         per_all_people_f.sex%TYPE;
        l_DATE_OF_BIRTH               per_all_people_f.DATE_OF_BIRTH%TYPE;
        l_per_information1            per_all_people_f.per_information1%TYPE;
        l_contact_person_id           per_contact_relationships.contact_person_id %TYPE;
        l_per_comment_id              per_all_people_f.comment_id%TYPE;
        l_name_combination_warning    BOOLEAN;
        l_assign_payroll_warning      BOOLEAN;
        l_orig_hire_warning           BOOLEAN;


--        CURSOR c_pre_contact
--        IS
--            SELECT --employee_number,
--                   last_name, first_name, middle_names, sex, con.OBJECT_VERSION_NUMBER,con.contact_person_id
--              FROM per_all_people_f p,
--                   per_contact_relationships con
--             WHERE con.business_group_id = p.business_group_id
--               AND p.business_group_id   = p_business_group_id
--               AND con.contact_person_id = p.person_id
--               AND con.contact_type      = p_contact_type
--               AND con.person_id         = p_person_id
--               AND p_start_date BETWEEN p.effective_start_date
--                                    AND p.effective_end_date;

--        r_pre_contact                  c_pre_contact%ROWTYPE;

    BEGIN
        g_module_name := 'update_contact_rel';

       -- l_start_date                  := p_start_date;
--        l_last_name                   := p_last_name;
--        l_first_name                  := p_first_name;
--        l_middle_name                 := p_middle_name;
--        l_attribute12                 := p_attribute12;


--        OPEN c_pre_contact;

--        FETCH c_pre_contact
--         INTO r_pre_contact;

--        CLOSE c_pre_contact;

        BEGIN
                Fnd_File.put_line(Fnd_File.LOG, 'update_contact_rel - Before SELECT');
                SELECT employee_number, last_name, first_name, middle_names, sex, --p.DATE_OF_BIRTH,
                per_information1, con.OBJECT_VERSION_NUMBER,con.contact_person_id
                INTO   l_employee_number, l_last_name, l_first_name, l_middle_names, l_sex,-- l_DATE_OF_BIRTH,
                l_per_information1,l_per_object_version_number,l_contact_person_id
                  FROM per_all_people_f p,
                       per_contact_relationships con
                 WHERE con.business_group_id = p.business_group_id
                   AND p.business_group_id   = p_business_group_id
                   AND con.contact_person_id = p.person_id
                   AND con.contact_type      = p_contact_type
                   AND con.person_id         = p_person_id
                   AND p_start_date BETWEEN p.effective_start_date
                                        AND p.effective_end_date; --Just in case it was entered as P in the past, but will use the JP_ first

                Fnd_File.put_line(Fnd_File.LOG, 'update_contact_rel - After SELECT p_person_id ->'||p_person_id);
                Fnd_File.put_line(Fnd_File.LOG, 'update_contact_rel - After SELECT l_change ->'||l_change);
                l_change                      := 'N';
--                l_per_object_version_number   := r_pre_contact.object_version_number;
--                l_person_id                   := r_pre_contact.contact_person_id;
               -- l_employee_number             := r_pre_contact.employee_number;

                IF p_last_name IS NOT NULL
                THEN

                    IF    UPPER(l_last_name) <> UPPER(p_last_name)
                        OR l_last_name IS NULL
                    THEN
                        l_change := 'Y';

                    END IF;
--Fnd_File.put_line(Fnd_File.LOG, 'update_contact_rel - p_last_name ->'||l_last_name);
--Fnd_File.put_line(Fnd_File.LOG, 'update_contact_rel - p_last_name ->'||p_last_name);
--Fnd_File.put_line(Fnd_File.LOG, 'update_contact_rel - After p_last_name  l_change ->'||l_change);

                END IF;

                IF p_first_name IS NOT NULL
                THEN

                    IF    UPPER(l_first_name) <> UPPER(p_first_name)
                        OR l_first_name IS NULL
                    THEN
                        l_change := 'Y';

                    END IF;
--Fnd_File.put_line(Fnd_File.LOG, 'update_contact_rel - p_last_name ->'||l_first_name);
--Fnd_File.put_line(Fnd_File.LOG, 'update_contact_rel - p_last_name ->'||p_first_name);
--Fnd_File.put_line(Fnd_File.LOG, 'update_contact_rel - After first_name  l_change ->'||l_change);
                END IF;

                IF p_middle_names IS NOT NULL
                THEN

                    IF    UPPER(l_middle_names) <> UPPER(p_middle_names)
                        OR l_middle_names IS NULL
                    THEN
                        l_change := 'Y';

                    END IF;
--Fnd_File.put_line(Fnd_File.LOG, 'update_contact_rel - p_last_name ->'||l_middle_names);
--Fnd_File.put_line(Fnd_File.LOG, 'update_contact_rel - p_last_name ->'||p_middle_names);
--Fnd_File.put_line(Fnd_File.LOG, 'update_contact_rel - After middle_names l_change ->'||l_change);
                END IF;


                IF p_sex IS NOT NULL
                THEN

                    IF    l_sex <> p_sex
                        OR l_sex IS NULL
                    THEN
                        l_change := 'Y';

                    END IF;
--Fnd_File.put_line(Fnd_File.LOG, 'update_contact_rel - l_sex ->'||l_sex);
--Fnd_File.put_line(Fnd_File.LOG, 'update_contact_rel - p_sex ->'||p_sex);
--Fnd_File.put_line(Fnd_File.LOG, 'update_contact_rel - After p_sex l_change ->'||l_change);
                END IF;



Fnd_File.put_line(Fnd_File.LOG, '         ObjectVN:' || l_per_object_version_number);
Fnd_File.put_line(Fnd_File.LOG, '   Contact Change:' || l_change);

                Fnd_File.put_line(Fnd_File.LOG, 'update_contact_rel - Contact Change:' || l_change);

                IF l_change = 'N'
                THEN
                    RETURN;
                END IF;

                DBMS_OUTPUT.PUT_LINE ('Contact Relationship Change:' || l_change);

                /* API on contact doesn't change the names need to use update person */


        --        hr_contact_rel_api.update_contact_relationship
        --               (p_validate                          => false,
        --           p_effective_date                         => p_start_date,
        --           p_contact_relationship_id           => l_contact_relationship_id,
        --           p_business_group_id                 => p_business_group_id,
        ----           p_person_id                         => p_person_id,
        ----           p_contact_type                      => p_contact_type,
        ----           p_date_start                        => p_start_date,
        ----           p_date_end                          => p_start_date - 1,
        ----           p_last_name                         => p_last_name,
        ----           p_first_name                        => p_first_name,
        ----           p_middle_names                      => p_middle_names,
        ----           p_attribute12                       => p_attribute12,
        --                --IN OUT Parameters
        --                p_object_version_number         => l_per_object_version_number
        --               );
 Fnd_File.put_line(Fnd_File.LOG, 'update_contact_rel - Calling Hr_Person_Api.update_person' );
                Hr_Person_Api.update_person
                       (p_validate                      => FALSE,
                        p_effective_date                => p_start_date,
                        p_datetrack_update_mode         => 'CORRECTION',
                        p_person_id                     => l_contact_person_id,
                        p_last_name                     => p_last_name,
                        p_first_name                    => p_first_name,
                        p_middle_names                  => p_middle_names,
                        p_sex                           => p_sex,
                        p_per_information1              => NVL(l_per_information1,12), -- need to replace undisclosed value ??12 need to replace the lookup value once Shafi confirmed
--                        p_DATE_OF_BIRTH                 => l_DATE_OF_BIRTH,
--                        p_attribute_category            => 1631,
--                        p_attribute12                   => 'c',
                         --IN OUT Parameters
                        p_object_version_number         => l_per_object_version_number,
                        p_employee_number               => l_employee_number,
                        --OUT Parameters
                        p_effective_start_date          => l_per_effective_start_date,
                        p_effective_end_date            => l_per_effective_end_date,
                        p_full_name                     => l_full_name,
                        p_comment_id                    => l_per_comment_id,
                        p_name_combination_warning      => l_name_combination_warning,
                        p_assign_payroll_warning        => l_assign_payroll_warning,
                        p_orig_hire_warning             => l_orig_hire_warning
                       );

Fnd_File.put_line(Fnd_File.LOG, 'update_contact_rel - AFTER Calling Hr_Person_Api.update_person' );
        EXCEPTION
          WHEN NO_DATA_FOUND
          THEN
           Fnd_File.put_line(Fnd_File.LOG, 'update_contact_rel - NO_DATA_FOUND Calling create_contact_relationship' );
                        create_contact_relationship (
                              p_start_date             => p_start_date,
                              p_person_id              => p_person_id,
                              p_business_group_id      => p_business_group_id,
                              p_sex                    => p_sex,
                              p_last_name              => p_last_name,
                              p_first_name             => p_first_name,
                              p_middle_names           => p_middle_names,
                              p_contact_type           => p_contact_type);
          WHEN OTHERS
          THEN
             g_error_message := 'Error at update contact relationship names api - Search existing contact' || SQLERRM;
             g_label2           := 'Contact type';
             g_secondary_column := p_contact_type;
             g_label3           := 'Contact for Emp Person ID';
             g_secondary_column := p_person_id;

         RAISE skip_record;
        END;

    EXCEPTION
      WHEN OTHERS
      THEN
         g_error_message := 'Error at update contact relationship names api' || SQLERRM;
         g_label2           := 'Contact type';
         g_secondary_column := p_contact_type;

         RAISE skip_record;
    END;
/* 4.0.7 End */
    /*************************************************************************************************************
    -- PROCEDURE update_matchpoint
    -- Author: Elango Pandu
    -- Date:  Aug 21 2009
    -- Parameters:
    -- Description: This procedure updates matchpoint
    --
    -- Modification Log
    -- Version    Developer              Date         Description
    -- ---        ----------------    -----------     --------------------------------

    -- 1.10        CChan              Jan 18 2010     Hirepoint Integration Enhancements - IB07,IB08

    **************************************************************************************************************/
   PROCEDURE update_matchpoint (
                                p_business_group_id  IN  NUMBER,
                                p_person_id          IN  NUMBER,
                                p_employee_number    IN   VARCHAR2,
                                p_effective_date     IN  DATE,
                                p_segment_1          IN  VARCHAR2,
                                p_segment_2          IN  VARCHAR2,
                                p_segment_3          IN  VARCHAR2,
                                p_segment_4          IN  VARCHAR2,
                                p_segment_5          IN  VARCHAR2,
                                p_segment_6          IN  VARCHAR2,
                                p_segment_7          IN  VARCHAR2,
                                p_segment_8          IN  VARCHAR2,
                                p_segment_9          IN  VARCHAR2,
                                p_segment_10         IN  VARCHAR2,
                                p_segment_11         IN  VARCHAR2,
                                p_segment_12         IN  VARCHAR2,
                                p_segment_13         IN  VARCHAR2,
                                p_segment_14         IN  VARCHAR2,
                                p_segment_15         IN  VARCHAR2,
                                p_segment_16         IN  VARCHAR2,/* Version 1.10 */
                                p_segment_17         IN  VARCHAR2,/* Version 1.10 */
--                                p_segment_18         IN  VARCHAR2,/* Version 2.8 */
--                                p_segment_19         IN  VARCHAR2,/* Version 2.8 */
--                                p_segment_20         IN  VARCHAR2,/* Version 2.8 */
--                                p_segment_21         IN  VARCHAR2,/* Version 2.8 */
                                p_segment_22         IN  VARCHAR2, /* Version 3.0 */
                                p_segment_23         IN  VARCHAR2, /* Version 3.0 */
                                p_segment_24         IN  VARCHAR2, /* Version 3.0 */
                                p_segment_25         IN  VARCHAR2, /* Version 3.0 */
                                p_segment_26         IN  VARCHAR2, /* Version 3.0 */
                                p_segment_27         IN  VARCHAR2, /* Version 3.0 */
                                p_segment_28         IN  VARCHAR2, /* Version 3.0 */
                                p_segment_29         IN  VARCHAR2, /* Version 3.0 */
                                p_segment_30         IN  VARCHAR2 /* Version 3.0 */
                                      )
   IS
      l_success_flag    g_success_flag%TYPE;
      l_error_message   g_error_message%TYPE;

      v_effective_start_date   DATE;
      v_effective_end_date    DATE;
      v_date_to date;
      v_previous_date_from date;

      v_pea_object_version_number     NUMBER;
      v_id_flex_num   fnd_id_flex_structures_vl.id_flex_num%TYPE;
      v_person_analysis_id per_person_analyses.person_analysis_id%TYPE;
      v_analysis_criteria_id per_analysis_criteria.analysis_criteria_id%TYPE;

      v_segment1  per_analysis_criteria.segment1%TYPE;
      v_segment2  per_analysis_criteria.segment2%TYPE;
      v_segment3  per_analysis_criteria.segment3%TYPE;
      v_segment4  per_analysis_criteria.segment4%TYPE;
      v_segment5  per_analysis_criteria.segment5%TYPE;
      v_segment6  per_analysis_criteria.segment6%TYPE;
      v_segment7  per_analysis_criteria.segment7%TYPE;
      v_segment8  per_analysis_criteria.segment8%TYPE;
      v_segment9  per_analysis_criteria.segment9%TYPE;
      v_segment10  per_analysis_criteria.segment10%TYPE;
      v_segment11  per_analysis_criteria.segment11%TYPE;
      v_segment12  per_analysis_criteria.segment12%TYPE;
      v_segment13 per_analysis_criteria.segment13%TYPE;
      v_segment14  per_analysis_criteria.segment14%TYPE;
      v_segment15  per_analysis_criteria.segment15%TYPE;
      v_segment16  per_analysis_criteria.segment16%TYPE; /* Version 1.9 */
      v_segment17  per_analysis_criteria.segment17%TYPE; /* Version 1.9*/
--      v_segment18  per_analysis_criteria.segment18%TYPE; /*  2.8 */
--      v_segment19  per_analysis_criteria.segment19%TYPE; /*  2.8 */
--      v_segment20  per_analysis_criteria.segment20%TYPE; /*  2.8 */
--      v_segment21  per_analysis_criteria.segment21%TYPE; /*  2.8 */
      v_segment22  per_analysis_criteria.segment22%TYPE; /*  3.0 */
      v_segment23  per_analysis_criteria.segment23%TYPE; /*  3.0 */
      v_segment24  per_analysis_criteria.segment24%TYPE; /*  3.0 */
      v_segment25  per_analysis_criteria.segment25%TYPE; /*  3.0 */
      v_segment26  per_analysis_criteria.segment26%TYPE; /*  3.0 */
      v_segment27  per_analysis_criteria.segment27%TYPE; /*  3.0 */
      v_segment28  per_analysis_criteria.segment28%TYPE; /*  3.0 */
      v_segment29  per_analysis_criteria.segment29%TYPE; /*  3.0 */
      v_segment30  per_analysis_criteria.segment30%TYPE; /*  3.0 */
      /* Version 1.9  BEGIN*/
      l_segment1  per_analysis_criteria.segment1%TYPE;
      l_segment2  per_analysis_criteria.segment2%TYPE;
      l_segment3  per_analysis_criteria.segment3%TYPE;
      l_segment4  per_analysis_criteria.segment4%TYPE;
      l_segment5  per_analysis_criteria.segment5%TYPE;
      l_segment6  per_analysis_criteria.segment6%TYPE;
      l_segment7  per_analysis_criteria.segment7%TYPE;
      l_segment8  per_analysis_criteria.segment8%TYPE;
      l_segment9  per_analysis_criteria.segment9%TYPE;
      l_segment10  per_analysis_criteria.segment10%TYPE;
      l_segment11  per_analysis_criteria.segment11%TYPE;
      l_segment12  per_analysis_criteria.segment12%TYPE;
      l_segment13 per_analysis_criteria.segment13%TYPE;
      l_segment14  per_analysis_criteria.segment14%TYPE;
      l_segment15  per_analysis_criteria.segment15%TYPE;
      l_segment16  per_analysis_criteria.segment16%TYPE;
      l_segment17  per_analysis_criteria.segment17%TYPE;
     /* Version 1.9 END */
--      l_segment18  per_analysis_criteria.segment18%TYPE; /*  2.8 */
--      l_segment19  per_analysis_criteria.segment19%TYPE; /*  2.8 */
--      l_segment20  per_analysis_criteria.segment20%TYPE; /*  2.8 */
--      l_segment21  per_analysis_criteria.segment21%TYPE; /*  2.8 */
      l_segment22  per_analysis_criteria.segment22%TYPE; /*  3.0 */
      l_segment23  per_analysis_criteria.segment23%TYPE; /*  3.0 */
      l_segment24  per_analysis_criteria.segment24%TYPE; /*  3.0 */
      l_segment25  per_analysis_criteria.segment25%TYPE; /*  3.0 */
      l_segment26  per_analysis_criteria.segment26%TYPE; /*  3.0 */
      l_segment27  per_analysis_criteria.segment27%TYPE; /*  3.0 */
      l_segment28  per_analysis_criteria.segment28%TYPE; /*  3.0 */
      l_segment29  per_analysis_criteria.segment29%TYPE; /*  3.0 */
      l_segment30  per_analysis_criteria.segment30%TYPE; /*  3.0 */

    CURSOR c_id_flex IS
    SELECT id_flex_num
    FROM fnd_id_flex_structures_vl
    WHERE structure_view_name = 'MATCHPOINT_DATA';


      CURSOR c_pre_contract IS
        SELECT  pa.person_analysis_id
                ,ac.ANALYSIS_CRITERIA_ID /* 3.1 */ ,pa.date_from
                ,pa.object_version_number       
		  --START R12.2 Upgrade Remediation		
          /*FROM  hr.per_person_analyses pa,			-- Commented code by IXPRAVEEN-ARGANO,14-july-2023
                hr.per_analysis_criteria ac*/
		  FROM  apps.per_person_analyses pa,		--  code Added by IXPRAVEEN-ARGANO,   14-july-2023
                apps.per_analysis_criteria ac		
				--END R12.2.12 Upgrade remediation		
         WHERE pa.analysis_criteria_id = ac.analysis_criteria_id
           AND pa.id_flex_num = v_id_flex_num
           AND pa.person_id = p_person_id
           AND date_from = (SELECT MAX(pa1.date_from)
                            --FROM  hr.per_person_analyses pa1			-- Commented code by IXPRAVEEN-ARGANO,14-july-2023
                            FROM  APPS.per_person_analyses pa1          --  code Added by IXPRAVEEN-ARGANO,   14-july-2023
                            where pa1.id_flex_num = v_id_flex_num
                            AND pa1.person_id = p_person_id);

   BEGIN
      g_module_name := 'update_Matchpoint';

       OPEN c_id_flex;
       FETCH c_id_flex INTO v_id_flex_num;
       CLOSE c_id_flex;

       OPEN c_pre_contract;
       FETCH c_pre_contract INTO v_person_analysis_id,v_analysis_criteria_id,v_previous_date_from
             ,v_pea_object_version_number;
       CLOSE c_pre_contract;


      IF v_person_analysis_id IS NOT NULL THEN


          v_date_to := p_effective_date - 1;

          IF v_previous_date_from >= v_date_to THEN

              /* FORCED TO End date the existing record with the day before current effective date*/

              hr_sit_api.update_sit
                        (p_validate                     => FALSE
                        ,p_person_analysis_id           => v_person_analysis_id
                        ,p_pea_object_version_number    => v_pea_object_version_number
                        ,p_analysis_criteria_id         => v_analysis_criteria_id
                        ,p_date_from                    => v_date_to
                        ,p_date_to                      => v_date_to
                        );


          ELSE

               /* End date the existing record */
               hr_sit_api.update_sit
                            (p_validate                     => FALSE
                            ,p_person_analysis_id           => v_person_analysis_id
                            ,p_pea_object_version_number    => v_pea_object_version_number
                            ,p_analysis_criteria_id         => v_analysis_criteria_id
                            ,p_date_to                      => v_date_to
                            );
          END IF;

      END IF;

        /* Rehire - Create Matchpoint' */

        v_analysis_criteria_id := NULL;

        l_segment16 := substr(p_segment_16,1,150);

        hr_sit_api.create_sit
            (p_person_id                  =>  p_person_id,
             p_business_group_id          =>  p_business_group_id,
             p_id_flex_num                =>  v_id_flex_num,
             p_effective_date             =>  p_effective_date,
             p_date_from                  =>  p_effective_date,
             p_segment1                   =>  p_segment_1,
             p_segment2                   =>  p_segment_2,
             p_segment3                   =>  p_segment_3,
             p_segment4                   =>  p_segment_4,
             p_segment5                   =>  p_segment_5,
             p_segment6                   =>  p_segment_6,
             p_segment7                   =>  p_segment_7,
             p_segment8                   =>  p_segment_8,
             p_segment9                   =>  p_segment_9,
             p_segment10                  =>  p_segment_10,
             p_segment11                  =>  p_segment_11,
             p_segment12                  =>  p_segment_12,
             p_segment13                  =>  p_segment_13,
             p_segment14                  =>  p_segment_14,
             p_segment15                  =>  p_segment_15,
             p_segment16                  =>  l_segment16,  /* Version 1.9 */
             p_segment17                  =>  p_segment_17,  /* Version 1.9 */
--             p_segment18                  =>  p_segment_18, /* Version 2.8 */
--             p_segment19                  =>  p_segment_19, /* Version 2.8 */
--             p_segment20                  =>  p_segment_20, /* Version 2.8 */
--             p_segment21                  =>  p_segment_21, /* Version 2.8 */
             p_segment22                  =>  p_segment_22, /* Version 3.0 */
             p_segment23                  =>  p_segment_23, /* Version 3.0 */
             p_segment24                  =>  p_segment_24, /* Version 3.0 */
             p_segment25                  =>  p_segment_25, /* Version 3.0 */
             p_segment26                  =>  p_segment_26, /* Version 3.0 */
             p_segment27                  =>  p_segment_27, /* Version 3.0 */
             p_segment28                  =>  p_segment_28, /* Version 3.0 */
             p_segment29                  =>  p_segment_29, /* Version 3.0 */
             p_segment30                  =>  p_segment_30, /* Version 3.0 */
             p_analysis_criteria_id       =>  v_analysis_criteria_id,
             p_person_analysis_id         =>  v_person_analysis_id,
             p_pea_object_version_number  =>  v_pea_object_version_number);

   EXCEPTION
      WHEN api_error
      THEN
      Fnd_File.put_line(Fnd_File.LOG, 'Error at update matchpoint api:'||DBMS_UTILITY.FORMAT_ERROR_STACK );
         g_error_message    := 'Error at update matchpoint api' || l_error_message;
         g_label2           := 'Employee Number';
         g_secondary_column := p_employee_number;
         RAISE skip_record;
      WHEN OTHERS
      THEN
      Fnd_File.put_line(Fnd_File.LOG, 'Other Error at update matchpoint api:'||DBMS_UTILITY.FORMAT_ERROR_STACK );
         g_error_message    := 'Other Error at update matchpoint api' || SQLERRM;
         g_label2           := 'Employee Number';
         g_secondary_column := p_employee_number;
         RAISE skip_record;
   END update_matchpoint;

/******************************************************************

   Procedure update_hireiq
    -- Author: Christiane chan
    -- Date:  May 12 2014
    -- Parameters:
    -- Description: This procedure updates HireIQ special infomraiotn
    -- Modification Log
    -- Version    Developer              Date         Description
    -- ---        ----------------    -----------     --------------------------------
    -- 1.0        Christiane chan     May 12 2014     Initial Delivery through 3.4
    --
    -- Modification Log

    -- Version    Developer              Date         Description
    -- ---        ----------------    -----------     --------------------------------

*********************************************************************/
   PROCEDURE update_hireiq (    p_business_group_id  IN  NUMBER,
                                p_person_id          IN  NUMBER,
                                p_employee_number    IN   VARCHAR2,
                                p_effective_date     IN  DATE,
                                p_segment_1          IN  VARCHAR2,
                                p_segment_3          IN  VARCHAR2,
                                p_segment_6          IN  VARCHAR2,
                                p_segment_9          IN  VARCHAR2,
                                p_segment_12         IN  VARCHAR2,
                                p_segment_15         IN  VARCHAR2,
                                p_segment_18         IN  VARCHAR2,
                                p_segment_21         IN  VARCHAR2
                                      )
   IS
      l_success_flag    g_success_flag%TYPE;
      l_error_message   g_error_message%TYPE;

      v_date_to             date;
      v_previous_date_from         date;

      v_pea_object_version_number         NUMBER;
      v_id_flex_num               fnd_id_flex_structures_vl.id_flex_num%TYPE;
      v_person_analysis_id         per_person_analyses.person_analysis_id%TYPE;
      v_analysis_criteria_id         per_analysis_criteria.analysis_criteria_id%TYPE;

      CURSOR c_id_flex IS
      SELECT id_flex_num
      FROM fnd_id_flex_structures_vl
      WHERE structure_view_name = 'TELETECH_HIREIQ';


      CURSOR c_pre_contract IS
        SELECT  pa.person_analysis_id
                ,ac.ANALYSIS_CRITERIA_ID ,pa.date_from
                ,pa.object_version_number
		  --START R12.2 Upgrade Remediation		
          /*FROM  hr.per_person_analyses pa,			-- Commented code by IXPRAVEEN-ARGANO,14-july-2023
                hr.per_analysis_criteria ac*/
		  FROM  apps.per_person_analyses pa,		--  code Added by IXPRAVEEN-ARGANO,   14-july-2023
                apps.per_analysis_criteria ac		
				--END R12.2.12 Upgrade remediation		
         WHERE pa.analysis_criteria_id = ac.analysis_criteria_id
           AND pa.id_flex_num = v_id_flex_num
           AND pa.person_id = p_person_id
           AND date_from = (SELECT MAX(pa1.date_from)
                            --FROM  hr.per_person_analyses pa1			-- Commented code by IXPRAVEEN-ARGANO,14-july-2023
                            FROM  APPS.per_person_analyses pa1			--  code Added by IXPRAVEEN-ARGANO,   14-july-2023
                            where pa1.id_flex_num = v_id_flex_num
                            AND pa1.person_id = p_person_id);

   BEGIN
      g_module_name := 'update_hireiq';

       OPEN c_id_flex;
       FETCH c_id_flex INTO v_id_flex_num;
       CLOSE c_id_flex;

       OPEN c_pre_contract;
       FETCH c_pre_contract INTO v_person_analysis_id,v_analysis_criteria_id,v_previous_date_from
             ,v_pea_object_version_number;
       CLOSE c_pre_contract;


      IF v_person_analysis_id IS NOT NULL THEN


          v_date_to := p_effective_date - 1;

          IF v_previous_date_from >= v_date_to THEN

              /* FORCED TO End date the existing record with the day before current effective date*/

              hr_sit_api.update_sit
                        (p_validate                     => FALSE
                        ,p_person_analysis_id           => v_person_analysis_id
                        ,p_pea_object_version_number    => v_pea_object_version_number
                        ,p_analysis_criteria_id         => v_analysis_criteria_id
                        ,p_date_from                    => v_date_to
                        ,p_date_to                      => v_date_to
                        );


          ELSE

               /* End date the existing record */
               hr_sit_api.update_sit
                            (p_validate                     => FALSE
                            ,p_person_analysis_id           => v_person_analysis_id
                            ,p_pea_object_version_number    => v_pea_object_version_number
                            ,p_analysis_criteria_id         => v_analysis_criteria_id
                            ,p_date_to                      => v_date_to
                            );
          END IF;

      END IF;

        /* Rehire - Create hireIQ' */

        v_analysis_criteria_id := NULL;

        hr_sit_api.create_sit
            (p_person_id                  =>  p_person_id,
             p_business_group_id          =>  p_business_group_id,
             p_id_flex_num                =>  v_id_flex_num,
             p_effective_date             =>  p_effective_date,
             p_date_from                  =>  p_effective_date,
             p_segment1                   =>  p_segment_1,
             p_segment3                   =>  p_segment_3,
             p_segment6                   =>  p_segment_6,
             p_segment9                   =>  p_segment_9,
             p_segment12                  =>  p_segment_12,
             p_segment15                  =>  p_segment_15,
             p_segment18                  =>  p_segment_18,
             p_segment21                  =>  p_segment_21,
             p_analysis_criteria_id       =>  v_analysis_criteria_id,
             p_person_analysis_id         =>  v_person_analysis_id,
             p_pea_object_version_number  =>  v_pea_object_version_number);

   EXCEPTION
      WHEN api_error
      THEN
         g_error_message    := 'Error at update HireIQ api' || l_error_message;
         g_label2           := 'Employee Number';
         g_secondary_column := p_employee_number;
         RAISE skip_record;
      WHEN OTHERS
      THEN
         g_error_message    := 'Other Error at update HireIQ api' || SQLERRM;
         g_label2           := 'Employee Number';
         g_secondary_column := p_employee_number;
         RAISE skip_record;
   END update_hireiq;

    /*************************************************************************************************************
    -- PROCEDURE update_matchpoint
    -- Author: Elango Pandu
    -- Date:  Aug 21 2009
    -- Parameters:
    -- Description: This procedure updates matchpoint
    --
    -- Modification Log
    -- Version    Developer              Date         Description
    -- ---        ----------------    -----------     --------------------------------

    -- 1.10        CChan              Jan 18 2010     Hirepoint Integration Enhancements - IB07,IB08

    **************************************************************************************************************/
   PROCEDURE update_matchpoint_bad2 (
                                p_business_group_id  IN  NUMBER,
                                p_person_id          IN  NUMBER,
                                p_employee_number    IN   VARCHAR2,
                                p_effective_date     IN  DATE,
                                p_segment_1          IN  VARCHAR2,
                                p_segment_2          IN  VARCHAR2,
                                p_segment_3          IN  VARCHAR2,
                                p_segment_4          IN  VARCHAR2,
                                p_segment_5          IN  VARCHAR2,
                                p_segment_6          IN  VARCHAR2,
                                p_segment_7          IN  VARCHAR2,
                                p_segment_8          IN  VARCHAR2,
                                p_segment_9          IN  VARCHAR2,
                                p_segment_10         IN  VARCHAR2,
                                p_segment_11         IN  VARCHAR2,
                                p_segment_12         IN  VARCHAR2,
                                p_segment_13         IN  VARCHAR2,
                                p_segment_14         IN  VARCHAR2,
                                p_segment_15         IN  VARCHAR2,
                                p_segment_16         IN  VARCHAR2,/* Version 1.10 */
                                p_segment_17         IN  VARCHAR2,/* Version 1.10 */
                                p_segment_18         IN  VARCHAR2,/* Version 2.8 */
                                p_segment_19         IN  VARCHAR2,/* Version 2.8 */
                                p_segment_20         IN  VARCHAR2,/* Version 2.8 */
                                p_segment_21         IN  VARCHAR2,/* Version 2.8 */
                                p_segment_22         IN  VARCHAR2, /* Version 3.0 */
                                p_segment_23         IN  VARCHAR2, /* Version 3.0 */
                                p_segment_24         IN  VARCHAR2, /* Version 3.0 */
                                p_segment_25         IN  VARCHAR2, /* Version 3.0 */
                                p_segment_26         IN  VARCHAR2, /* Version 3.0 */
                                p_segment_27         IN  VARCHAR2, /* Version 3.0 */
                                p_segment_28         IN  VARCHAR2, /* Version 3.0 */
                                p_segment_29         IN  VARCHAR2, /* Version 3.0 */
                                p_segment_30         IN  VARCHAR2 /* Version 3.0 */
                                      )
   IS
      l_success_flag    g_success_flag%TYPE;
      l_error_message   g_error_message%TYPE;

      v_effective_start_date   DATE;
      v_effective_end_date    DATE;

      v_pea_object_version_number     NUMBER;
      v_id_flex_num   fnd_id_flex_structures_vl.id_flex_num%TYPE;
      v_person_analysis_id per_person_analyses.person_analysis_id%TYPE;
      v_analysis_criteria_id per_analysis_criteria.analysis_criteria_id%TYPE;

      v_segment1  per_analysis_criteria.segment1%TYPE;
      v_segment2  per_analysis_criteria.segment2%TYPE;
      v_segment3  per_analysis_criteria.segment3%TYPE;
      v_segment4  per_analysis_criteria.segment4%TYPE;
      v_segment5  per_analysis_criteria.segment5%TYPE;
      v_segment6  per_analysis_criteria.segment6%TYPE;
      v_segment7  per_analysis_criteria.segment7%TYPE;
      v_segment8  per_analysis_criteria.segment8%TYPE;
      v_segment9  per_analysis_criteria.segment9%TYPE;
      v_segment10  per_analysis_criteria.segment10%TYPE;
      v_segment11  per_analysis_criteria.segment11%TYPE;
      v_segment12  per_analysis_criteria.segment12%TYPE;
      v_segment13 per_analysis_criteria.segment13%TYPE;
      v_segment14  per_analysis_criteria.segment14%TYPE;
      v_segment15  per_analysis_criteria.segment15%TYPE;
      v_segment16  per_analysis_criteria.segment16%TYPE; /* Version 1.9 */
      v_segment17  per_analysis_criteria.segment17%TYPE; /* Version 1.9*/
      v_segment18  per_analysis_criteria.segment18%TYPE; /*  2.8 */
      v_segment19  per_analysis_criteria.segment19%TYPE; /*  2.8 */
      v_segment20  per_analysis_criteria.segment20%TYPE; /*  2.8 */
      v_segment21  per_analysis_criteria.segment21%TYPE; /*  2.8 */
      v_segment22  per_analysis_criteria.segment22%TYPE; /*  3.0 */
      v_segment23  per_analysis_criteria.segment23%TYPE; /*  3.0 */
      v_segment24  per_analysis_criteria.segment24%TYPE; /*  3.0 */
      v_segment25  per_analysis_criteria.segment25%TYPE; /*  3.0 */
      v_segment26  per_analysis_criteria.segment26%TYPE; /*  3.0 */
      v_segment27  per_analysis_criteria.segment27%TYPE; /*  3.0 */
      v_segment28  per_analysis_criteria.segment28%TYPE; /*  3.0 */
      v_segment29  per_analysis_criteria.segment29%TYPE; /*  3.0 */
      v_segment30  per_analysis_criteria.segment30%TYPE; /*  3.0 */
      /* Version 1.9  BEGIN*/
      l_segment1  per_analysis_criteria.segment1%TYPE;
      l_segment2  per_analysis_criteria.segment2%TYPE;
      l_segment3  per_analysis_criteria.segment3%TYPE;
      l_segment4  per_analysis_criteria.segment4%TYPE;
      l_segment5  per_analysis_criteria.segment5%TYPE;
      l_segment6  per_analysis_criteria.segment6%TYPE;
      l_segment7  per_analysis_criteria.segment7%TYPE;
      l_segment8  per_analysis_criteria.segment8%TYPE;
      l_segment9  per_analysis_criteria.segment9%TYPE;
      l_segment10  per_analysis_criteria.segment10%TYPE;
      l_segment11  per_analysis_criteria.segment11%TYPE;
      l_segment12  per_analysis_criteria.segment12%TYPE;
      l_segment13 per_analysis_criteria.segment13%TYPE;
      l_segment14  per_analysis_criteria.segment14%TYPE;
      l_segment15  per_analysis_criteria.segment15%TYPE;
      l_segment16  per_analysis_criteria.segment16%TYPE;
      l_segment17  per_analysis_criteria.segment17%TYPE;
     /* Version 1.9 END */
      l_segment18  per_analysis_criteria.segment18%TYPE; /*  2.8 */
      l_segment19  per_analysis_criteria.segment19%TYPE; /*  2.8 */
      l_segment20  per_analysis_criteria.segment20%TYPE; /*  2.8 */
      l_segment21  per_analysis_criteria.segment21%TYPE; /*  2.8 */
      l_segment22  per_analysis_criteria.segment22%TYPE; /*  3.0 */
      l_segment23  per_analysis_criteria.segment23%TYPE; /*  3.0 */
      l_segment24  per_analysis_criteria.segment24%TYPE; /*  3.0 */
      l_segment25  per_analysis_criteria.segment25%TYPE; /*  3.0 */
      l_segment26  per_analysis_criteria.segment26%TYPE; /*  3.0 */
      l_segment27  per_analysis_criteria.segment27%TYPE; /*  3.0 */
      l_segment28  per_analysis_criteria.segment28%TYPE; /*  3.0 */
      l_segment29  per_analysis_criteria.segment29%TYPE; /*  3.0 */
      l_segment30  per_analysis_criteria.segment30%TYPE; /*  3.0 */

    CURSOR c_id_flex IS
    SELECT id_flex_num
    FROM fnd_id_flex_structures_vl
    WHERE structure_view_name = 'MATCHPOINT_DATA';


      CURSOR c_pre_contract IS
        SELECT  pa.person_analysis_id
                ,ac.ANALYSIS_CRITERIA_ID /* 3.1 */
                ,pa.object_version_number,ac.segment1,ac.segment2
                ,ac.segment3,ac.segment4,ac.segment5,ac.segment6,ac.segment7,ac.segment8
                ,ac.segment9,ac.segment10,ac.segment11,ac.segment12,ac.segment13,ac.segment14,ac.segment15
                ,ac.segment16,ac.segment17 /* Version 1.9 */
                ,ac.segment18,ac.segment19 /* Version 1.9 */
                ,ac.segment20,ac.segment21 /* Version 1.9 */
                ,ac.segment22 /* Version 3.0 */
                ,ac.segment23 /* Version 3.0 */
                ,ac.segment24 /* Version 3.0 */
                ,ac.segment25 /* Version 3.0 */
                ,ac.segment26 /* Version 3.0 */
                ,ac.segment27 /* Version 3.0 */
                ,ac.segment28 /* Version 3.0 */
                ,ac.segment29 /* Version 3.0 */
                ,ac.segment30 /* Version 3.0 */
          --START R12.2 Upgrade Remediation		
          /*FROM  hr.per_person_analyses pa,			-- Commented code by IXPRAVEEN-ARGANO,14-july-2023
                hr.per_analysis_criteria ac*/
		  FROM  apps.per_person_analyses pa,		--  code Added by IXPRAVEEN-ARGANO,   14-july-2023
                apps.per_analysis_criteria ac		
				--END R12.2.12 Upgrade remediation
         WHERE pa.analysis_criteria_id = ac.analysis_criteria_id
           AND pa.id_flex_num = v_id_flex_num
           AND pa.person_id = p_person_id
           AND date_from = (SELECT MAX(pa1.date_from)
                            --FROM  hr.per_person_analyses pa1			-- Commented code by IXPRAVEEN-ARGANO,14-july-2023
                            FROM  apps.per_person_analyses pa1          --  code Added by IXPRAVEEN-ARGANO,   14-july-2023
                            where pa1.id_flex_num = v_id_flex_num
                            AND pa1.person_id = p_person_id);

   BEGIN
      g_module_name := 'update_Matchpoint';

       OPEN c_id_flex;
       FETCH c_id_flex INTO v_id_flex_num;
       CLOSE c_id_flex;

       OPEN c_pre_contract;
       FETCH c_pre_contract INTO v_person_analysis_id,v_analysis_criteria_id /* 3.1 */
             ,v_pea_object_version_number,v_segment1,v_segment2,v_segment3
             ,v_segment4,v_segment5,v_segment6,v_segment7,v_segment8,v_segment9,v_segment10,v_segment11,v_segment12
             ,v_segment13,v_segment14,v_segment15
             ,v_segment16,v_segment17 /* Version 1.10 */
             ,v_segment18,v_segment19 /* 2.8 */
             ,v_segment20,v_segment21 /* 2.8 */
             ,v_segment22 /* 3.0 */
             ,v_segment23 /* 3.0 */
             ,v_segment24 /* 3.0 */
             ,v_segment25 /* 3.0 */
             ,v_segment26 /* 3.0 */
             ,v_segment27 /* 3.0 */
             ,v_segment28 /* 3.0 */
             ,v_segment29 /* 3.0 */
             ,v_segment30 /* 3.0 */
              ;
       CLOSE c_pre_contract;


      IF v_person_analysis_id IS NOT NULL THEN

          /* Version 1.9  BEGIN */

            IF p_segment_1 IS NOT NULL
            THEN
                 l_segment1 := p_segment_1;
            ELSE
                 l_segment1 := v_segment1;
            END IF;

            IF p_segment_2 IS NOT NULL
            THEN
                 l_segment2 := p_segment_2;
            ELSE
                 l_segment2 := v_segment2;
            END IF;

            IF p_segment_3 IS NOT NULL
            THEN
             l_segment3 := p_segment_3;
            ELSE
                 l_segment3 := v_segment3;
            END IF;

            IF p_segment_4 IS NOT NULL
            THEN
                 l_segment4 := p_segment_4;
            ELSE
                 l_segment4 := v_segment4;
            END IF;

            IF p_segment_5 IS NOT NULL
            THEN
                 l_segment5 := p_segment_5;
            ELSE
             l_segment5 := v_segment5;
            END IF;


            IF p_segment_6 IS NOT NULL
            THEN
                 l_segment6 := p_segment_6;
            ELSE
                 l_segment6 := v_segment6;
            END IF;


            IF p_segment_7 IS NOT NULL
            THEN
             l_segment7 := p_segment_7;
            ELSE
                 l_segment7 := v_segment7;
            END IF;

            IF p_segment_8 IS NOT NULL
            THEN
                 l_segment8 := p_segment_8;

            ELSE
                 l_segment8 := v_segment8;
            END IF;


            IF p_segment_9 IS NOT NULL
            THEN
                 l_segment9 := p_segment_9;
            ELSE
                 l_segment9 := v_segment9;
            END IF;

            IF p_segment_10 IS NOT NULL
            THEN
                 l_segment10 := p_segment_10;
            ELSE
                 l_segment10 := v_segment10;
            END IF;

            IF p_segment_11 IS NOT NULL
            THEN
                 l_segment11 := p_segment_11;
            ELSE
                 l_segment11 := v_segment11;
            END IF;

            IF p_segment_12 IS NOT NULL
            THEN
                 l_segment12 := p_segment_12;
            ELSE
                 l_segment12 := v_segment12;
            END IF;

            IF p_segment_13 IS NOT NULL
            THEN
                 l_segment13 := p_segment_13;
            ELSE
                 l_segment13 := v_segment13;
            END IF;

            IF p_segment_14 IS NOT NULL
            THEN
                 l_segment14 := p_segment_14;
            ELSE
                 l_segment14 := v_segment14;
            END IF;

            IF p_segment_15 IS NOT NULL
            THEN
             l_segment15 := p_segment_15;
            ELSE
                 l_segment15 := v_segment15;
            END IF;

            IF p_segment_16 IS NOT NULL
            THEN
             l_segment16 := substr(p_segment_16,1,150);
            ELSE
             l_segment16 := substr(p_segment_16,1,150);
            END IF;


            IF p_segment_17 IS NOT NULL
            THEN
                 l_segment17 := p_segment_17;
            ELSE
                 l_segment17 := v_segment17;
            END IF;

      /* Version 1.9  END */

      /* Version 2.8  BEGIN */
            IF p_segment_18 IS NOT NULL
            THEN
                 l_segment18 := p_segment_18;
            ELSE
                 l_segment18 := v_segment18;
            END IF;

            IF p_segment_19 IS NOT NULL
            THEN
                 l_segment19 := p_segment_18;
            ELSE
                 l_segment19 := v_segment18;
            END IF;

            IF p_segment_20 IS NOT NULL
            THEN
                 l_segment20 := p_segment_20;
            ELSE
                 l_segment20 := v_segment20;
            END IF;

            IF p_segment_21 IS NOT NULL
            THEN
                 l_segment21 := p_segment_21;
            ELSE
                 l_segment21 := v_segment21;
            END IF;

      /* Version 2.8  END */

      /* Version 3.0  BEGIN */
            IF p_segment_22 IS NOT NULL
            THEN
                 l_segment22 := p_segment_22;
            ELSE
                 l_segment22 := v_segment22;
            END IF;

            IF p_segment_23 IS NOT NULL
            THEN
                 l_segment23 := p_segment_23;
            ELSE
                 l_segment23 := v_segment23;
            END IF;

            IF p_segment_24 IS NOT NULL
            THEN
                 l_segment24 := p_segment_24;
            ELSE
                 l_segment24 := v_segment24;
            END IF;

            IF p_segment_25 IS NOT NULL
            THEN
                 l_segment25 := p_segment_25;
            ELSE
                 l_segment25 := v_segment25;
            END IF;

            IF p_segment_26 IS NOT NULL
            THEN
                 l_segment26 := p_segment_26;
            ELSE
                 l_segment26 := v_segment26;
            END IF;

            IF p_segment_27 IS NOT NULL
            THEN
                 l_segment27 := p_segment_27;
            ELSE
                 l_segment27 := v_segment27;
            END IF;

            IF p_segment_28 IS NOT NULL
            THEN
                 l_segment28 := p_segment_28;
            ELSE
                 l_segment28 := v_segment28;
            END IF;

            IF p_segment_29 IS NOT NULL
            THEN
                 l_segment29 := p_segment_29;
            ELSE
                 l_segment29 := v_segment29;
            END IF;

            IF p_segment_30 IS NOT NULL
            THEN
                 l_segment30 := p_segment_30;
            ELSE
                 l_segment30 := v_segment30;
            END IF;

      /* Version 3.0 END */
            hr_sit_api.update_sit
                    (p_validate                     => FALSE
                    ,p_person_analysis_id           => v_person_analysis_id
                    ,p_pea_object_version_number    => v_pea_object_version_number
                    ,p_analysis_criteria_id         => v_analysis_criteria_id
                    ,p_date_from                    => p_effective_date
                    ,p_segment1                     => l_segment1
                    ,p_segment2                     => l_segment2
                    ,p_segment3                     => l_segment3
                    ,p_segment4                     => l_segment4
                    ,p_segment5                     => l_segment5
                    ,p_segment6                     => l_segment6
                    ,p_segment7                     => l_segment7
                    ,p_segment8                     => l_segment8
                    ,p_segment9                     => l_segment9
                    ,p_segment10                    => l_segment10
                    ,p_segment11                    => l_segment11
                    ,p_segment12                    => l_segment12
                    ,p_segment13                    => l_segment13
                    ,p_segment14                    => l_segment14
                    ,p_segment15                    => l_segment15
                    ,p_segment16                    => l_segment16 /* Version 1.9 */
                    ,p_segment17                    => l_segment17 /* Version 1.9 */
                    ,p_segment18                    => l_segment18 /* Version 2.8 */
                    ,p_segment19                    => l_segment19 /* Version 2.8 */
                    ,p_segment20                    => l_segment20 /* Version 2.8 */
                    ,p_segment21                    => l_segment21 /* Version 2.8 */
                    ,p_segment22                    => l_segment22 /* Version 3.0 */
                    ,p_segment23                    => l_segment23 /* Version 3.0 */
                    ,p_segment24                    => l_segment24 /* Version 3.0 */
                    ,p_segment25                    => l_segment25 /* Version 3.0 */
                    ,p_segment26                    => l_segment26 /* Version 3.0 */
                    ,p_segment27                    => l_segment27 /* Version 3.0 */
                    ,p_segment28                    => l_segment28 /* Version 3.0 */
                    ,p_segment29                    => l_segment29 /* Version 3.0 */
                    ,p_segment30                    => l_segment30 /* Version 3.0 */
                    );

      ELSE
        l_segment15 := substr(p_segment_15,1,150);
        l_segment16 := substr(p_segment_16,1,150);

        hr_sit_api.create_sit
            (p_person_id                  =>  p_person_id,
             p_business_group_id          =>  p_business_group_id,
             p_id_flex_num                =>  v_id_flex_num,
             p_effective_date             =>  p_effective_date,
             p_date_from                  =>  p_effective_date,
             p_segment1                   =>  p_segment_1,
             p_segment2                   =>  p_segment_2,
             p_segment3                   =>  p_segment_3,
             p_segment4                   =>  p_segment_4,
             p_segment5                   =>  p_segment_5,
             p_segment6                   =>  p_segment_6,
             p_segment7                   =>  p_segment_7,
             p_segment8                   =>  p_segment_8,
             p_segment9                   =>  p_segment_9,
             p_segment10                  =>  p_segment_10,
             p_segment11                  =>  p_segment_11,
             p_segment12                  =>  p_segment_12,
             p_segment13                  =>  p_segment_13,
             p_segment14                  =>  p_segment_14,
             p_segment15                  =>  p_segment_15,
             p_segment16                  =>  l_segment16,  /* Version 1.9 */
             p_segment17                  =>  p_segment_17,  /* Version 1.9 */
             p_segment18                  =>  p_segment_18, /* Version 2.8 */
             p_segment19                  =>  p_segment_19, /* Version 2.8 */
             p_segment20                  =>  p_segment_20, /* Version 2.8 */
             p_segment21                  =>  p_segment_21, /* Version 2.8 */
             p_segment22                  =>  p_segment_22, /* Version 3.0 */
             p_segment23                  =>  p_segment_23, /* Version 3.0 */
             p_segment24                  =>  p_segment_24, /* Version 3.0 */
             p_segment25                  =>  p_segment_25, /* Version 3.0 */
             p_segment26                  =>  p_segment_26, /* Version 3.0 */
             p_segment27                  =>  p_segment_27, /* Version 3.0 */
             p_segment28                  =>  p_segment_28, /* Version 3.0 */
             p_segment29                  =>  p_segment_29, /* Version 3.0 */
             p_segment30                  =>  p_segment_30, /* Version 3.0 */
             p_analysis_criteria_id       =>  v_analysis_criteria_id,
             p_person_analysis_id         =>  v_person_analysis_id,
             p_pea_object_version_number  =>  v_pea_object_version_number);
      END IF;

   EXCEPTION
      WHEN api_error
      THEN
         g_error_message    := 'Error at update contract api' || l_error_message;
         g_label2           := 'Employee Number';
         g_secondary_column := p_employee_number;
         RAISE skip_record;
      WHEN OTHERS
      THEN
         g_error_message    := 'Other Error at update contract api' || SQLERRM;
         g_label2           := 'Employee Number';
         g_secondary_column := p_employee_number;
         RAISE skip_record;
   END update_matchpoint_bad2;
   /*************************************************************************************************************
    -- PROCEDURE update_matchpoint
    -- Author: Elango Pandu
    -- Date:  Aug 21 2009
    -- Parameters:
    -- Description: This procedure updates matchpoint
    --
    -- Modification Log
    -- Version    Developer              Date         Description
    -- ---        ----------------    -----------     --------------------------------

    -- 1.10        CChan              Jan 18 2010     Hirepoint Integration Enhancements - IB07,IB08

    **************************************************************************************************************/
    PROCEDURE update_matchpoint_bad (
                                p_business_group_id  IN  NUMBER,
                                p_person_id          IN  NUMBER,
                                p_employee_number    IN   VARCHAR2,
                                p_effective_date     IN  DATE,
                                p_segment_1          IN  VARCHAR2,
                                p_segment_2          IN  VARCHAR2,
                                p_segment_3          IN  VARCHAR2,
                                p_segment_4          IN  VARCHAR2,
                                p_segment_5          IN  VARCHAR2,
                                p_segment_6          IN  VARCHAR2,
                                p_segment_7          IN  VARCHAR2,
                                p_segment_8          IN  VARCHAR2,
                                p_segment_9          IN  VARCHAR2,
                                p_segment_10         IN  VARCHAR2,
                                p_segment_11         IN  VARCHAR2,
                                p_segment_12         IN  VARCHAR2,
                                p_segment_13         IN  VARCHAR2,
                                p_segment_14         IN  VARCHAR2,
                                p_segment_15         IN  VARCHAR2,
                                p_segment_16         IN  VARCHAR2,/* Version 1.10 */
                                p_segment_17         IN  VARCHAR2 /* Version 1.10 */       )
   IS
      l_success_flag    g_success_flag%TYPE;
      l_error_message   g_error_message%TYPE;
      v_effective_start_date   DATE;
      v_effective_end_date    DATE;

      v_pea_object_version_number     NUMBER;
      v_id_flex_num   fnd_id_flex_structures_vl.id_flex_num%TYPE;
      v_person_analysis_id per_person_analyses.person_analysis_id%TYPE;
      v_analysis_criteria_id per_analysis_criteria.analysis_criteria_id%TYPE;

      v_segment1  per_analysis_criteria.segment1%TYPE;
      v_segment2  per_analysis_criteria.segment2%TYPE;
      v_segment3  per_analysis_criteria.segment3%TYPE;
      v_segment4  per_analysis_criteria.segment4%TYPE;
      v_segment5  per_analysis_criteria.segment5%TYPE;
      v_segment6  per_analysis_criteria.segment6%TYPE;
      v_segment7  per_analysis_criteria.segment7%TYPE;
      v_segment8  per_analysis_criteria.segment8%TYPE;
      v_segment9  per_analysis_criteria.segment9%TYPE;
      v_segment10  per_analysis_criteria.segment10%TYPE;
      v_segment11  per_analysis_criteria.segment11%TYPE;
      v_segment12  per_analysis_criteria.segment12%TYPE;
      v_segment13 per_analysis_criteria.segment13%TYPE;
      v_segment14  per_analysis_criteria.segment14%TYPE;
      v_segment15  per_analysis_criteria.segment15%TYPE;
      v_segment16  per_analysis_criteria.segment16%TYPE; /* Version 1.9 */
      v_segment17  per_analysis_criteria.segment17%TYPE; /* Version 1.9*/
      /* Version 1.9  BEGIN*/
      l_segment1  per_analysis_criteria.segment1%TYPE;
      l_segment2  per_analysis_criteria.segment2%TYPE;
      l_segment3  per_analysis_criteria.segment3%TYPE;
      l_segment4  per_analysis_criteria.segment4%TYPE;
      l_segment5  per_analysis_criteria.segment5%TYPE;
      l_segment6  per_analysis_criteria.segment6%TYPE;
      l_segment7  per_analysis_criteria.segment7%TYPE;
      l_segment8  per_analysis_criteria.segment8%TYPE;
      l_segment9  per_analysis_criteria.segment9%TYPE;
      l_segment10  per_analysis_criteria.segment10%TYPE;
      l_segment11  per_analysis_criteria.segment11%TYPE;
      l_segment12  per_analysis_criteria.segment12%TYPE;
      l_segment13  per_analysis_criteria.segment13%TYPE;
      l_segment14  per_analysis_criteria.segment14%TYPE;
      l_segment15  per_analysis_criteria.segment15%TYPE;
      l_segment16  per_analysis_criteria.segment16%TYPE;
      l_segment17  per_analysis_criteria.segment17%TYPE;
     /* Version 1.9 END */

      CURSOR c_id_flex IS
      SELECT id_flex_num
      FROM fnd_id_flex_structures_vl
      WHERE structure_view_name = 'MATCHPOINT_DATA';

      CURSOR c_pre_contract IS
        SELECT  pa.person_analysis_id,pa.object_version_number,ac.segment1,ac.segment2
                ,ac.segment3,ac.segment4,ac.segment5,ac.segment6,ac.segment7,ac.segment8
                ,ac.segment9,ac.segment10,ac.segment11,ac.segment12,ac.segment13,ac.segment14,ac.segment15
                ,ac.segment16,ac.segment17 /* Version 1.9 */
          --START R12.2 Upgrade Remediation		
          /*FROM  hr.per_person_analyses pa,			-- Commented code by IXPRAVEEN-ARGANO,14-july-2023
                hr.per_analysis_criteria ac*/
		  FROM  apps.per_person_analyses pa,		--  code Added by IXPRAVEEN-ARGANO,   14-july-2023
                apps.per_analysis_criteria ac		
				--END R12.2.12 Upgrade remediation
         WHERE pa.analysis_criteria_id = ac.analysis_criteria_id
           AND pa.id_flex_num = v_id_flex_num
           AND pa.person_id = p_person_id
           AND SYSDATE BETWEEN date_from AND NVL (date_to,'31-DEC-4712');

      CURSOR c_pre_contract2 IS
        SELECT  pa.person_analysis_id,pa.object_version_number
          --START R12.2 Upgrade Remediation		
          /*FROM  hr.per_person_analyses pa,			-- Commented code by IXPRAVEEN-ARGANO,14-july-2023
                hr.per_analysis_criteria ac*/
		  FROM  apps.per_person_analyses pa,		--  code Added by IXPRAVEEN-ARGANO,   14-july-2023
                apps.per_analysis_criteria ac		
				--END R12.2.12 Upgrade remediation
         WHERE pa.analysis_criteria_id = ac.analysis_criteria_id
           AND pa.id_flex_num = v_id_flex_num
           AND pa.person_id = p_person_id
           AND SYSDATE BETWEEN date_from AND NVL (date_to,'31-DEC-4712');


  BEGIN
      g_module_name := 'update_Matchpoint';

      --Fnd_File.put_line (Fnd_File.log,'1');


       OPEN c_id_flex;
       FETCH c_id_flex INTO v_id_flex_num;
       CLOSE c_id_flex;

       OPEN c_pre_contract;
       FETCH c_pre_contract INTO v_person_analysis_id,v_pea_object_version_number,v_segment1,v_segment2,v_segment3
             ,v_segment4,v_segment5,v_segment6,v_segment7,v_segment8,v_segment9,v_segment10,v_segment11,v_segment12
             ,v_segment13,v_segment14,v_segment15
             ,v_segment16,v_segment17; /* Version 1.10 */
       CLOSE c_pre_contract;

      /* Version 1.9  BEGIN */
        IF p_segment_1 IS NOT NULL
        THEN
             l_segment1 := p_segment_1;
        ELSE
             l_segment1 := v_segment1;
        END IF;

        IF p_segment_2 IS NOT NULL
        THEN
             l_segment2 := p_segment_2;
        ELSE
             l_segment2 := v_segment2;
        END IF;

        IF p_segment_3 IS NOT NULL
        THEN
             l_segment3 := p_segment_3;
        ELSE
             l_segment3 := v_segment3;
        END IF;

        IF p_segment_4 IS NOT NULL
        THEN
             l_segment4 := p_segment_4;
        ELSE
             l_segment4 := v_segment4;
        END IF;

        IF p_segment_5 IS NOT NULL
        THEN
             l_segment5 := p_segment_5;
        ELSE
             l_segment5 := v_segment5;
        END IF;


        IF p_segment_6 IS NOT NULL
        THEN
             l_segment6 := p_segment_6;
        ELSE
             l_segment6 := v_segment6;
        END IF;


        IF p_segment_7 IS NOT NULL
        THEN
             l_segment7 := p_segment_7;
        ELSE
             l_segment7 := v_segment7;
        END IF;

        IF p_segment_8 IS NOT NULL
        THEN
             l_segment8 := p_segment_8;

        ELSE
             l_segment8 := v_segment8;
        END IF;


        IF p_segment_9 IS NOT NULL
        THEN
             l_segment9 := p_segment_9;
        ELSE
             l_segment9 := v_segment9;
        END IF;

        IF p_segment_10 IS NOT NULL
        THEN
             l_segment10 := p_segment_10;
        ELSE
             l_segment10 := v_segment10;
        END IF;

        IF p_segment_11 IS NOT NULL
        THEN
             l_segment11 := p_segment_11;
        ELSE
             l_segment11 := v_segment11;
        END IF;

        IF p_segment_12 IS NOT NULL
        THEN
             l_segment12 := p_segment_12;
        ELSE
             l_segment12 := v_segment12;
        END IF;

        IF p_segment_13 IS NOT NULL
        THEN
             l_segment13 := p_segment_13;
        ELSE
             l_segment13 := v_segment13;
        END IF;

        IF p_segment_14 IS NOT NULL
        THEN
             l_segment14 := p_segment_14;
        ELSE
             l_segment14 := v_segment14;
        END IF;

        IF p_segment_15 IS NOT NULL
        THEN
             l_segment15 := p_segment_15;
        ELSE
             l_segment15 := v_segment15;
        END IF;

        IF p_segment_16 IS NOT NULL
        THEN
             l_segment16 := substr(p_segment_16,1,150);
        ELSE
             l_segment16 := substr(p_segment_16,1,150);
        END IF;


        IF p_segment_17 IS NOT NULL
        THEN
             l_segment17 := p_segment_17;
        ELSE
             l_segment17 := v_segment17;
        END IF;

      /* Version 1.9  END */

    BEGIN

      --Fnd_File.put_line (Fnd_File.log,'2');

      IF v_person_analysis_id IS NOT NULL THEN
      --Fnd_File.put_line (Fnd_File.log,'3');


      g_module_name := 'Rehire Endate Matchpoint';
       /* End date the existing record */
       hr_sit_api.update_sit
                    (p_validate                     => FALSE
                    ,p_person_analysis_id           => v_person_analysis_id
                    ,p_pea_object_version_number    => v_pea_object_version_number
                    ,p_analysis_criteria_id         => v_analysis_criteria_id
                    ,p_date_to                      => p_effective_date - 1
                    );
      Fnd_File.put_line (Fnd_File.log,'4');

      END IF;
      Fnd_File.put_line (Fnd_File.log,'5');


    EXCEPTION
      WHEN api_error
      THEN
         g_error_message    := 'Error at Endate Rehire Matchpoint api' || l_error_message;
         g_label2           := 'Employee Number';
         g_secondary_column := p_employee_number;
         RAISE skip_record;
    WHEN OTHERS
     THEN
         g_error_message    := 'Other Error at Rehire Enddate Matchpoint api' || SQLERRM;
         g_label2           := 'Employee Number';
         g_secondary_column := p_employee_number;
         RAISE skip_record;
    END;

      --Fnd_File.put_line (Fnd_File.log,'6');

     /*
       OPEN c_pre_contract2;
       FETCH c_pre_contract2 INTO v_person_analysis_id,v_pea_object_version_number;
       CLOSE c_pre_contract2;
       */
         v_person_analysis_id := null;
         v_pea_object_version_number := null;
      g_module_name := 'Rehire Create Matchpoint';

      --Fnd_File.put_line (Fnd_File.log,'l_segment16 is '||l_segment16);

        hr_sit_api.create_sit
            (p_person_id                  =>  p_person_id,
             p_business_group_id          =>  p_business_group_id,
             p_id_flex_num                =>  v_id_flex_num,
             p_effective_date             =>  p_effective_date,
             p_date_from                  =>  p_effective_date,
             p_segment1                   =>  l_segment1,
             p_segment2                   =>  l_segment2,
             p_segment3                   =>  l_segment3,
             p_segment4                   =>  l_segment4,
             p_segment5                   =>  l_segment5,
             p_segment6                   =>  l_segment6,
             p_segment7                   =>  l_segment7,
             p_segment8                   =>  l_segment8,
             p_segment9                   =>  l_segment9,
             p_segment10                  =>  l_segment10,
             p_segment11                  =>  l_segment11,
             p_segment12                  =>  l_segment12,
             p_segment13                  =>  l_segment13,
             p_segment14                  =>  l_segment14,
             p_segment15                  =>  l_segment15,
             p_segment16                  =>  l_segment16, /* Version 1.10 */
             p_segment17                  =>  l_segment17, /* Version 1.10 */
             p_analysis_criteria_id       =>  v_analysis_criteria_id,
             p_person_analysis_id         =>  v_person_analysis_id,
             p_pea_object_version_number  =>  v_pea_object_version_number);
      Fnd_File.put_line (Fnd_File.log,'v_analysis_criteria_id is '||v_analysis_criteria_id);
      Fnd_File.put_line (Fnd_File.log,'v_person_analysis_id is '||v_person_analysis_id);


            l_success_flag := 'Y';

EXCEPTION
      WHEN api_error
      THEN
      --Fnd_File.put_line (Fnd_File.log,'API ERROR ');

         g_error_message    := 'Error at Rehire Create Matchpoint api' || l_error_message;
         g_label2           := 'Employee Number';
         g_secondary_column := p_employee_number;
         RAISE skip_record;
      WHEN OTHERS
      THEN
      --Fnd_File.put_line (Fnd_File.log,'OTEHR ERROR ');
         g_error_message    := 'Other Error at  Rehire Create Matchpoint api' || SQLERRM;
         g_label2           := 'Employee Number';
         g_secondary_column := p_employee_number;
         RAISE skip_record;
   END update_matchpoint_bad;

/*7.3.5 */
/******************************************************************

   Procedure Create OEAD
    -- Author: Christiane chan
    -- Date:  Nov 12,2020
    -- Parameters:
    -- Description: This procedure creates OEAD special information
    -- Modification Log
    -- Version    Developer              Date         Description
    -- ---        ----------------    -----------     --------------------------------
    -- 1.0        Christiane chan     Nov 12,2020     Initial Delivery through 7.3.5
    --
    -- Modification Log

    -- Version    Developer              Date         Description
    -- ---        ----------------    -----------     --------------------------------

*********************************************************************/

    PROCEDURE create_OEAD(
                                p_business_group_id  IN  NUMBER,
                                p_person_id          IN  NUMBER,
                                p_effective_date     IN  DATE,
                                p_segment_1          IN  VARCHAR2,
                                p_segment_2          IN  VARCHAR2,
                                p_segment_3          IN  VARCHAR2,
								p_segment_4          IN  VARCHAR2
                              ) IS


    v_analysis_criteria_id      per_person_analyses.analysis_criteria_id%TYPE;
    v_person_analysis_id        per_person_analyses.person_analysis_id%TYPE;
    v_pea_object_version_number per_person_analyses.object_version_number%TYPE;
    v_id_flex   fnd_id_flex_structures_vl.id_flex_num%TYPE;

    l_success_flag              g_success_flag%TYPE;
    l_error_message             g_error_message%TYPE;
    l_segment1                  per_analysis_criteria.segment1%TYPE;
    l_segment2                  per_analysis_criteria.segment2%TYPE;
    l_segment3                  per_analysis_criteria.segment3%TYPE;
	l_segment4                  per_analysis_criteria.segment4%TYPE;


    CURSOR c_id_flex IS
    SELECT id_flex_num
    FROM fnd_id_flex_structures_vl
    WHERE  ID_FLEX_STRUCTURE_CODE = 'GRC_OAED_DETAILS';

   BEGIN
      g_module_name := 'create_OEAD';

       OPEN c_id_flex;
       FETCH c_id_flex INTO v_id_flex;
       CLOSE c_id_flex;

        hr_sit_api.create_sit
            (p_person_id                  =>  p_person_id,
             p_business_group_id          =>  p_business_group_id,
             p_id_flex_num                =>  v_id_flex,
             p_effective_date             =>  p_effective_date,
             p_date_from                  =>  p_effective_date,
             p_segment1                   =>  p_segment_1,
             p_segment2                   =>  p_segment_2,
             p_segment3                   =>  p_segment_3,
			 p_segment4                   =>  p_segment_4,
             p_analysis_criteria_id       =>  v_analysis_criteria_id,
             p_person_analysis_id         =>  v_person_analysis_id,
             p_pea_object_version_number  =>  v_pea_object_version_number);

            l_success_flag := 'Y';

    EXCEPTION
    WHEN OTHERS
    THEN
        l_success_flag      := 'N';
        l_error_message     := SQLERRM;
        g_error_message     := 'Error others in Create OEAD' || SQLERRM;
        g_label2            := 'Person Id';
        g_secondary_column  := p_person_id;
        RAISE skip_record;
   END  create_OEAD;

/******************************************************************

   Procedure update_OEAD
    -- Author: Christiane chan
    -- Date:  Nov 12,2020
    -- Parameters:
    -- Description: This procedure updates OEADspecial infomraiotn
    -- Modification Log
    -- Version    Developer              Date         Description
    -- ---        ----------------    -----------     --------------------------------
    -- 1.0        Christiane chan     Nov 12,2020     Initial Delivery through 7.3.5
    --
    -- Modification Log

    -- Version    Developer              Date         Description
    -- ---        ----------------    -----------     --------------------------------

*********************************************************************/
   PROCEDURE update_OEAD (      p_business_group_id  IN  NUMBER,
                                p_person_id          IN  NUMBER,
                                p_employee_number    IN  VARCHAR2,
                                p_effective_date     IN  DATE,
                                p_segment_1          IN  VARCHAR2,
                                p_segment_2          IN  VARCHAR2,
                                p_segment_3          IN  VARCHAR2,
								p_segment_4          IN  VARCHAR2
                                      )
   IS
      l_success_flag    g_success_flag%TYPE;
      l_error_message   g_error_message%TYPE;

      v_date_to             date;
      v_previous_date_from         date;

      v_pea_object_version_number     NUMBER;
      v_id_flex_num                   fnd_id_flex_structures_vl.id_flex_num%TYPE;
      v_person_analysis_id            per_person_analyses.person_analysis_id%TYPE;
      v_analysis_criteria_id          per_analysis_criteria.analysis_criteria_id%TYPE;

      CURSOR c_id_flex IS
      SELECT id_flex_num
      FROM fnd_id_flex_structures_vl
      WHERE  ID_FLEX_STRUCTURE_CODE = 'GRC_OAED_DETAILS';


      CURSOR c_pre_contract IS
        SELECT  pa.person_analysis_id
                ,ac.ANALYSIS_CRITERIA_ID ,pa.date_from
                ,pa.object_version_number
          --START R12.2 Upgrade Remediation		
          /*FROM  hr.per_person_analyses pa,			-- Commented code by IXPRAVEEN-ARGANO,14-july-2023
                hr.per_analysis_criteria ac*/
		  FROM  apps.per_person_analyses pa,		--  code Added by IXPRAVEEN-ARGANO,   14-july-2023
                apps.per_analysis_criteria ac		
				--END R12.2.12 Upgrade remediation
         WHERE pa.analysis_criteria_id = ac.analysis_criteria_id
           AND pa.id_flex_num = v_id_flex_num
           AND pa.person_id = p_person_id
           AND date_from = (SELECT MAX(pa1.date_from)
                            --FROM  hr.per_person_analyses pa1			-- Commented code by IXPRAVEEN-ARGANO,14-july-2023
                            FROM  apps.per_person_analyses pa1          --  code Added by IXPRAVEEN-ARGANO,   14-july-2023
                            where pa1.id_flex_num = v_id_flex_num
                            AND pa1.person_id = p_person_id);

   BEGIN
      g_module_name := 'update_OEAD';

       OPEN c_id_flex;
       FETCH c_id_flex INTO v_id_flex_num;
       CLOSE c_id_flex;

       OPEN c_pre_contract;
       FETCH c_pre_contract INTO v_person_analysis_id,v_analysis_criteria_id,v_previous_date_from
             ,v_pea_object_version_number;
       CLOSE c_pre_contract;


      IF v_person_analysis_id IS NOT NULL THEN


          v_date_to := p_effective_date - 1;

          IF v_previous_date_from >= v_date_to THEN

              /* FORCED TO End date the existing record with the day before current effective date*/

              hr_sit_api.update_sit
                        (p_validate                     => FALSE
                        ,p_person_analysis_id           => v_person_analysis_id
                        ,p_pea_object_version_number    => v_pea_object_version_number
                        ,p_analysis_criteria_id         => v_analysis_criteria_id
                        ,p_date_from                    => v_date_to
                        ,p_date_to                      => v_date_to
                        );


          ELSE

               /* End date the existing record */
               hr_sit_api.update_sit
                            (p_validate                     => FALSE
                            ,p_person_analysis_id           => v_person_analysis_id
                            ,p_pea_object_version_number    => v_pea_object_version_number
                            ,p_analysis_criteria_id         => v_analysis_criteria_id
                            ,p_date_to                      => v_date_to
                            );
          END IF;

      END IF;

        /* Rehire - Create hireIQ' */

        v_analysis_criteria_id := NULL;

        hr_sit_api.create_sit
            (p_person_id                  =>  p_person_id,
             p_business_group_id          =>  p_business_group_id,
             p_id_flex_num                =>  v_id_flex_num,
             p_effective_date             =>  p_effective_date,
             p_date_from                  =>  p_effective_date,
             p_segment1                   =>  p_segment_1,
             p_segment2                   =>  p_segment_2,
             p_segment3                   =>  p_segment_3,
			 p_segment4                   =>  p_segment_4,
             p_analysis_criteria_id       =>  v_analysis_criteria_id,
             p_person_analysis_id         =>  v_person_analysis_id,
             p_pea_object_version_number  =>  v_pea_object_version_number);

   EXCEPTION
      WHEN api_error
      THEN
         g_error_message    := 'Error at update OEADapi' || l_error_message;
         g_label2           := 'Employee Number';
         g_secondary_column :=  p_employee_number;
         RAISE skip_record;
      WHEN OTHERS
      THEN
         g_error_message    := 'Other Error at update OEADapi' || SQLERRM;
         g_label2           := 'Employee Number';
         g_secondary_column := p_employee_number;
         RAISE skip_record;
   END update_OEAD;
/* 7.3.5 */

/******************************************************************

   Procedure CREATE_COLUMBIA_SIT
    -- Author: Rajesh Koneru
    -- Date:  May 27, 2022
    -- Parameters:
    -- Description: This procedure updates special information for Columbia employees
    -- Modification Log
    -- Version    Developer              Date         Description
    -- ---        ----------------    -----------     --------------------------------
    -- 1.0        Koneru Rajesh       May 27 ,2022    Initial Delivery through 8.5

*********************************************************************/
PROCEDURE CREATE_COLUMBIA_SIT(
                                p_business_group_id  IN  NUMBER,
                                p_person_id          IN  NUMBER,
                                p_effective_date     IN  DATE,
                                p_segment_1          IN  VARCHAR2,
                              --  p_segment_2          IN  VARCHAR2,
                                p_segment_3          IN  VARCHAR2,
								p_segment_4          IN  VARCHAR2,
								p_segment_5          IN  VARCHAR2,
								p_segment_6          IN  VARCHAR2,
								p_segment_7          IN  VARCHAR2,
								p_segment_8          IN  VARCHAR2,
								p_segment_9          IN  VARCHAR2,
								p_segment_10          IN  VARCHAR2,
								p_segment_11          IN  VARCHAR2,
								p_segment_12          IN  VARCHAR2,
								p_segment_13          IN  VARCHAR2,
								p_segment_14          IN  VARCHAR2,
								p_segment_24          IN  VARCHAR2,
								p_segment_25          IN  VARCHAR2,
                                                                p_segment_26          IN  VARCHAR2,
                                                                p_segment_27          IN  VARCHAR2,
                                                                p_segment_28          IN  VARCHAR2,
                                                                p_segment_29          IN  VARCHAR2
							) IS


    v_analysis_criteria_id      per_person_analyses.analysis_criteria_id%TYPE;
    v_person_analysis_id        per_person_analyses.person_analysis_id%TYPE;
    v_pea_object_version_number per_person_analyses.object_version_number%TYPE;
    v_id_flex                   fnd_id_flex_structures_vl.id_flex_num%TYPE;

    l_success_flag              g_success_flag%TYPE;
    l_error_message             g_error_message%TYPE;
    l_segment1                  per_analysis_criteria.segment1%TYPE;
    l_segment2                  per_analysis_criteria.segment2%TYPE;
    l_segment3                  per_analysis_criteria.segment3%TYPE;
	l_segment4                  per_analysis_criteria.segment4%TYPE;
	l_segment5                  per_analysis_criteria.segment5%TYPE;
	l_segment6                  per_analysis_criteria.segment6%TYPE;
	l_segment7                  per_analysis_criteria.segment7%TYPE;
	l_segment8                  per_analysis_criteria.segment8%TYPE;
	l_segment9                  per_analysis_criteria.segment9%TYPE;
	l_segment10                  per_analysis_criteria.segment10%TYPE;
	l_segment11                  per_analysis_criteria.segment11%TYPE;
	l_segment12                  per_analysis_criteria.segment12%TYPE;
	l_segment13                  per_analysis_criteria.segment13%TYPE;
    l_segment14                  per_analysis_criteria.segment14%TYPE;
	l_segment24                  per_analysis_criteria.segment24%TYPE;
	l_segment25                  per_analysis_criteria.segment25%TYPE;
	l_segment26                  per_analysis_criteria.segment24%TYPE;
	l_segment27                  per_analysis_criteria.segment25%TYPE;


   /* CURSOR c_id_flex IS
    SELECT id_flex_num
    FROM fnd_id_flex_structures_vl
    WHERE  ID_FLEX_STRUCTURE_CODE = 'TTEC_CO_CSI_EMP_DATA';*/

     CURSOR c_id_flex IS
    select id_flex_num from fnd_id_flex_structures
    where structure_view_name='Colombia CSI Info';--'TTEC Columbia Emp CSI';

   BEGIN
      g_module_name := 'CREATE_COLUMBIA_SIT';

       OPEN c_id_flex;
       FETCH c_id_flex INTO v_id_flex;
       CLOSE c_id_flex;

fnd_file.put_line(fnd_file.output, 'v_id_flex'||v_id_flex) ;
fnd_file.put_line(fnd_file.output, 'p_person_id'||p_person_id) ;
fnd_file.put_line(fnd_file.output, 'p_business_group_id'||p_business_group_id) ;

fnd_file.put_line(fnd_file.output, 'p_effective_date'||p_effective_date) ;
fnd_file.put_line(fnd_file.output, 'p_effective_date'||p_effective_date) ;

fnd_file.put_line(fnd_file.output, 'p_segment_1'||p_segment_1) ;
--fnd_file.put_line(fnd_file.output, 'p_segment_2'||p_segment_2) ;
fnd_file.put_line(fnd_file.output, 'p_segment_3'||p_segment_3) ;
fnd_file.put_line(fnd_file.output, 'p_segment_4'||p_segment_4) ;
fnd_file.put_line(fnd_file.output, 'p_segment_5'||p_segment_5) ;
fnd_file.put_line(fnd_file.output, 'p_segment_6'||p_segment_6) ;
fnd_file.put_line(fnd_file.output, 'p_segment_7'||p_segment_7) ;
fnd_file.put_line(fnd_file.output, 'p_segment_8'||p_segment_8) ;
fnd_file.put_line(fnd_file.output, 'p_segment_9'||p_segment_9) ;
fnd_file.put_line(fnd_file.output, 'p_segment_10'||p_segment_10) ;
fnd_file.put_line(fnd_file.output, 'p_segment_11'||p_segment_11) ;
fnd_file.put_line(fnd_file.output, 'p_segment_12'||p_segment_12) ;
fnd_file.put_line(fnd_file.output, 'p_segment_13'||p_segment_13) ;
fnd_file.put_line(fnd_file.output, 'p_segment_14'||p_segment_14) ;
fnd_file.put_line(fnd_file.output, 'p_segment_24'||p_segment_24) ;
fnd_file.put_line(fnd_file.output, 'p_segment_25'||p_segment_25) ;
fnd_file.put_line(fnd_file.output, 'p_segment_26'||p_segment_26) ;
fnd_file.put_line(fnd_file.output, 'p_segment_27'||p_segment_27) ;
fnd_file.put_line(fnd_file.output, 'p_segment_28'||p_segment_28) ;
fnd_file.put_line(fnd_file.output, 'p_segment_29'||p_segment_29) ;

        hr_sit_api.create_sit
            (p_person_id                  =>  p_person_id,
             p_business_group_id          =>  p_business_group_id,
             p_id_flex_num                =>  v_id_flex,
             p_effective_date             =>  p_effective_date,
             p_date_from                  =>  p_effective_date,
             p_segment1                   =>  p_segment_1,
           --  p_segment2                   =>  p_segment_2,
             p_segment3                   =>  p_segment_3,
			 p_segment4                   =>  p_segment_4,
			 p_segment5                   =>  p_segment_5,
			 p_segment6                   =>  p_segment_6,
			 p_segment7                   =>  p_segment_7,
			 p_segment8                   =>  p_segment_8,
			 p_segment9                   =>  p_segment_9,
			 p_segment10                  =>  p_segment_10,
			 p_segment11                  =>  p_segment_11,
			 p_segment12                  =>  p_segment_12,
			 p_segment13                  =>  p_segment_13,
			 p_segment14                  =>  p_segment_14,
			 p_segment24                  =>  p_segment_24,
			 p_segment25                  =>  p_segment_25,
			 p_segment26                  =>  p_segment_26,
			 p_segment27                  =>  p_segment_27,
             p_segment28                  =>  p_segment_28,
             p_segment29                  => substr(p_segment_29,1,10), --to_date(substr(p_segment_29,1,10),'YYYY-MM-DD'),
			 p_analysis_criteria_id       =>  v_analysis_criteria_id,
             p_person_analysis_id         =>  v_person_analysis_id,
             p_pea_object_version_number  =>  v_pea_object_version_number);

            l_success_flag := 'Y';

fnd_file.put_line(fnd_file.output,'Successfully create SIT Feilds');

    EXCEPTION
    WHEN OTHERS
    THEN
        l_success_flag      := 'N';
        l_error_message     := SQLERRM;
        g_error_message     := 'Error others in Create Columbia SIT' || SQLERRM;
        g_label2            := 'Person Id';
        g_secondary_column  := p_person_id;
   END  CREATE_COLUMBIA_SIT;

/******************************************************************

   Procedure UPDATE_COLUMBIA_SIT
    -- Author: Koneru Rajesh
    -- Date:   May 27, 2022
    -- Parameters:
    -- Description: This procedure updates Fiscal special information for MEX employees
    -- Modification Log
    -- Version    Developer              Date         Description
    -- ---        ----------------    -----------     --------------------------------
    -- 1.0        Rajesh Koneru       May 27,2022     Initial Delivery through 8.5

*********************************************************************/
   PROCEDURE UPDATE_COLUMBIA_SIT (      p_business_group_id  IN  NUMBER,
                                p_person_id          IN  NUMBER,
                                p_employee_number    IN  VARCHAR2,
                                p_effective_date     IN  DATE,
                                p_segment_1          IN  VARCHAR2,
                              --  p_segment_2          IN  VARCHAR2,
                                p_segment_3          IN  VARCHAR2,
								p_segment_4          IN  VARCHAR2,
								p_segment_5          IN  VARCHAR2,
								p_segment_6          IN  VARCHAR2,
								p_segment_7          IN  VARCHAR2,
								p_segment_8          IN  VARCHAR2,
								p_segment_9          IN  VARCHAR2,
								p_segment_10          IN  VARCHAR2,
								p_segment_11          IN  VARCHAR2,
								p_segment_12          IN  VARCHAR2,
								p_segment_13          IN  VARCHAR2,
								p_segment_14          IN  VARCHAR2,
								p_segment_24          IN  VARCHAR2,
								p_segment_25          IN  VARCHAR2,
                                                                p_segment_26          IN  VARCHAR2,
                                                                p_segment_27          IN  VARCHAR2,
                                                                p_segment_28          IN  VARCHAR2,
                                                                 p_segment_29          IN  VARCHAR2
								)
   IS
      l_success_flag    g_success_flag%TYPE;
      l_error_message   g_error_message%TYPE;

      v_date_to                       date;
      v_previous_date_from            date;

      v_pea_object_version_number     NUMBER;
      v_id_flex_num                   fnd_id_flex_structures_vl.id_flex_num%TYPE;
      v_person_analysis_id            per_person_analyses.person_analysis_id%TYPE;
      v_analysis_criteria_id          per_analysis_criteria.analysis_criteria_id%TYPE;

     /* CURSOR c_id_flex IS
      SELECT id_flex_num
      FROM fnd_id_flex_structures_vl
      WHERE  ID_FLEX_STRUCTURE_CODE = 'TTEC_CO_CSI_EMP_DATA';*/
      CURSOR c_id_flex IS
    select id_flex_num from fnd_id_flex_structures
    where structure_view_name='Colombia CSI Info';--'TTEC Columbia Emp CSI';


      CURSOR c_pre_contract IS
        SELECT  pa.person_analysis_id
                ,ac.ANALYSIS_CRITERIA_ID ,pa.date_from
                ,pa.object_version_number
          --START R12.2 Upgrade Remediation		
          /*FROM  hr.per_person_analyses pa,			-- Commented code by IXPRAVEEN-ARGANO,14-july-2023
                hr.per_analysis_criteria ac*/
		  FROM  apps.per_person_analyses pa,		--  code Added by IXPRAVEEN-ARGANO,   14-july-2023
                apps.per_analysis_criteria ac		
				--END R12.2.12 Upgrade remediation
         WHERE pa.analysis_criteria_id = ac.analysis_criteria_id
           AND pa.id_flex_num = v_id_flex_num
           AND pa.person_id = p_person_id
           AND date_from = (SELECT MAX(pa1.date_from)
                            --FROM  hr.per_person_analyses pa1			-- Commented code by IXPRAVEEN-ARGANO,14-july-2023
                            FROM  apps.per_person_analyses pa1            --  code Added by IXPRAVEEN-ARGANO,   14-july-2023
                            where pa1.id_flex_num = v_id_flex_num
                            AND pa1.person_id = p_person_id);

   BEGIN
      g_module_name := 'UPDATE_FISCAL_SIT';

       OPEN c_id_flex;
       FETCH c_id_flex INTO v_id_flex_num;
       CLOSE c_id_flex;

       OPEN c_pre_contract;
       FETCH c_pre_contract INTO v_person_analysis_id,v_analysis_criteria_id,v_previous_date_from
             ,v_pea_object_version_number;
       CLOSE c_pre_contract;


      IF v_person_analysis_id IS NOT NULL THEN


          v_date_to := p_effective_date - 1;

          IF v_previous_date_from >= v_date_to THEN

              /* FORCED TO End date the existing record with the day before current effective date*/

              hr_sit_api.update_sit
                        (p_validate                     => FALSE
                        ,p_person_analysis_id           => v_person_analysis_id
                        ,p_pea_object_version_number    => v_pea_object_version_number
                        ,p_analysis_criteria_id         => v_analysis_criteria_id
                        ,p_date_from                    => v_date_to
                        ,p_date_to                      => v_date_to
                        );


          ELSE

               /* End date the existing record */
               hr_sit_api.update_sit
                            (p_validate                     => FALSE
                            ,p_person_analysis_id           => v_person_analysis_id
                            ,p_pea_object_version_number    => v_pea_object_version_number
                            ,p_analysis_criteria_id         => v_analysis_criteria_id
                            ,p_date_to                      => v_date_to
                            );
          END IF;

      END IF;

        /* Rehire - UPDATE_COLUMBIA_SIT' */

        v_analysis_criteria_id := NULL;

        hr_sit_api.create_sit
            (p_person_id                  =>  p_person_id,
             p_business_group_id          =>  p_business_group_id,
             p_id_flex_num                =>  v_id_flex_num,
             p_effective_date             =>  p_effective_date,
             p_date_from                  =>  p_effective_date,
             p_segment1                   =>  p_segment_1,
           --  p_segment2                   =>  p_segment_2,
             p_segment3                   =>  p_segment_3,
			 p_segment4                   =>  p_segment_4,
			 p_segment5                   =>  p_segment_5,
			 p_segment6                   =>  p_segment_6,
			 p_segment7                   =>  p_segment_7,
			 p_segment8                   =>  p_segment_8,
			 p_segment9                   =>  p_segment_9,
			 p_segment10                  =>  p_segment_10,
			 p_segment11                  =>  p_segment_11,
			 p_segment12                  =>  p_segment_12,
			 p_segment13                  =>  p_segment_13,
			 p_segment14                  =>  p_segment_14,
			 p_segment24                  =>  p_segment_24,
			 p_segment25                  =>  p_segment_25,
			 p_segment26                  =>  p_segment_26,
			 p_segment27                  =>  p_segment_27,
             p_segment28                  =>  p_segment_28,
             p_segment29                  =>  to_date(substr(p_segment_29,1,10),'YYYY-MM-DD'),
			 p_analysis_criteria_id       =>  v_analysis_criteria_id,
             p_person_analysis_id         =>  v_person_analysis_id,
             p_pea_object_version_number  =>  v_pea_object_version_number);

   EXCEPTION
      WHEN api_error
      THEN
         g_error_message    := 'Error at update UPDATE_COLUMBIA_SIT' || l_error_message;
         g_label2           := 'Employee Number';
         g_secondary_column :=  p_employee_number;
      WHEN OTHERS
      THEN
         g_error_message    := 'Other Error at update UPDATE_COLUMBIA_SIT' || SQLERRM;
         g_label2           := 'Employee Number';
         g_secondary_column := p_employee_number;

   END UPDATE_COLUMBIA_SIT;

/******************************************************************

   Procedure CREATE_FISCAL_SIT
    -- Author: Venkata Kovvuri
    -- Date:  Apr 04, 2022
    -- Parameters:
    -- Description: This procedure updates Fiscal special information for MEX employees
    -- Modification Log
    -- Version    Developer              Date         Description
    -- ---        ----------------    -----------     --------------------------------
    -- 1.0        Venkata Kovvuri     Apr 04 ,2022    Initial Delivery through 8.3

*********************************************************************/
PROCEDURE CREATE_FISCAL_SIT(
                                p_business_group_id  IN  NUMBER,
                                p_person_id          IN  NUMBER,
                                p_effective_date     IN  DATE,
                                p_segment_1          IN  VARCHAR2,
                                p_segment_2          IN  VARCHAR2,
                                p_segment_3          IN  VARCHAR2
							) IS


    v_analysis_criteria_id      per_person_analyses.analysis_criteria_id%TYPE;
    v_person_analysis_id        per_person_analyses.person_analysis_id%TYPE;
    v_pea_object_version_number per_person_analyses.object_version_number%TYPE;
    v_id_flex                   fnd_id_flex_structures_vl.id_flex_num%TYPE;

    l_success_flag              g_success_flag%TYPE;
    l_error_message             g_error_message%TYPE;
    l_segment1                  per_analysis_criteria.segment1%TYPE;
    l_segment2                  per_analysis_criteria.segment2%TYPE;
    l_segment3                  per_analysis_criteria.segment3%TYPE;


    CURSOR c_id_flex IS
    SELECT id_flex_num
    FROM fnd_id_flex_structures_vl
    WHERE  ID_FLEX_STRUCTURE_CODE = 'TTEC_MEX_EMP_FISCAL_DATA';

   BEGIN
      g_module_name := 'CREATE_FISCAL_SIT';

       OPEN c_id_flex;
       FETCH c_id_flex INTO v_id_flex;
       CLOSE c_id_flex;

        hr_sit_api.create_sit
            (p_person_id                  =>  p_person_id,
             p_business_group_id          =>  p_business_group_id,
             p_id_flex_num                =>  v_id_flex,
             p_effective_date             =>  p_effective_date,
             p_date_from                  =>  p_effective_date,
             p_segment1                   =>  p_segment_1,
             p_segment2                   =>  p_segment_2,
             p_segment3                   =>  p_segment_3,
			 p_analysis_criteria_id       =>  v_analysis_criteria_id,
             p_person_analysis_id         =>  v_person_analysis_id,
             p_pea_object_version_number  =>  v_pea_object_version_number);

            l_success_flag := 'Y';

    EXCEPTION
    WHEN OTHERS
    THEN
        l_success_flag      := 'N';
        l_error_message     := SQLERRM;
        g_error_message     := 'Error others in Create Fiscal SIT' || SQLERRM;
        g_label2            := 'Person Id';
        g_secondary_column  := p_person_id;
   END  CREATE_FISCAL_SIT;

/******************************************************************

   Procedure UPDATE_FISCAL_SIT
    -- Author: Christiane chan
    -- Date:  Nov 12,2020
    -- Parameters:
    -- Description: This procedure updates Fiscal special information for MEX employees
    -- Modification Log
    -- Version    Developer              Date         Description
    -- ---        ----------------    -----------     --------------------------------
    -- 1.0        Venkata Kovvuri     Apr 04,2022     Initial Delivery through 8.3

*********************************************************************/
   PROCEDURE UPDATE_FISCAL_SIT (      p_business_group_id  IN  NUMBER,
                                p_person_id          IN  NUMBER,
                                p_employee_number    IN  VARCHAR2,
                                p_effective_date     IN  DATE,
                                p_segment_1          IN  VARCHAR2,
                                p_segment_2          IN  VARCHAR2,
                                p_segment_3          IN  VARCHAR2
								)
   IS
      l_success_flag    g_success_flag%TYPE;
      l_error_message   g_error_message%TYPE;

      v_date_to                       date;
      v_previous_date_from            date;

      v_pea_object_version_number     NUMBER;
      v_id_flex_num                   fnd_id_flex_structures_vl.id_flex_num%TYPE;
      v_person_analysis_id            per_person_analyses.person_analysis_id%TYPE;
      v_analysis_criteria_id          per_analysis_criteria.analysis_criteria_id%TYPE;

      CURSOR c_id_flex IS
      SELECT id_flex_num
      FROM fnd_id_flex_structures_vl
      WHERE  ID_FLEX_STRUCTURE_CODE = 'TTEC_MEX_EMP_FISCAL_DATA';


      CURSOR c_pre_contract IS
        SELECT  pa.person_analysis_id
                ,ac.ANALYSIS_CRITERIA_ID ,pa.date_from
                ,pa.object_version_number
          --START R12.2 Upgrade Remediation		
          /*FROM  hr.per_person_analyses pa,			-- Commented code by IXPRAVEEN-ARGANO,14-july-2023
                hr.per_analysis_criteria ac*/
		  FROM  apps.per_person_analyses pa,		--  code Added by IXPRAVEEN-ARGANO,   14-july-2023
                apps.per_analysis_criteria ac		
				--END R12.2.12 Upgrade remediation
         WHERE pa.analysis_criteria_id = ac.analysis_criteria_id
           AND pa.id_flex_num = v_id_flex_num
           AND pa.person_id = p_person_id
           AND date_from = (SELECT MAX(pa1.date_from)
                            --FROM  hr.per_person_analyses pa1			-- Commented code by IXPRAVEEN-ARGANO,14-july-2023
                            FROM  apps.per_person_analyses pa1            --  code Added by IXPRAVEEN-ARGANO,   14-july-2023
                            where pa1.id_flex_num = v_id_flex_num
                            AND pa1.person_id = p_person_id);

   BEGIN
      g_module_name := 'UPDATE_FISCAL_SIT';

       OPEN c_id_flex;
       FETCH c_id_flex INTO v_id_flex_num;
       CLOSE c_id_flex;

       OPEN c_pre_contract;
       FETCH c_pre_contract INTO v_person_analysis_id,v_analysis_criteria_id,v_previous_date_from
             ,v_pea_object_version_number;
       CLOSE c_pre_contract;


      IF v_person_analysis_id IS NOT NULL THEN


          v_date_to := p_effective_date - 1;

          IF v_previous_date_from >= v_date_to THEN

              /* FORCED TO End date the existing record with the day before current effective date*/

              hr_sit_api.update_sit
                        (p_validate                     => FALSE
                        ,p_person_analysis_id           => v_person_analysis_id
                        ,p_pea_object_version_number    => v_pea_object_version_number
                        ,p_analysis_criteria_id         => v_analysis_criteria_id
                        ,p_date_from                    => v_date_to
                        ,p_date_to                      => v_date_to
                        );


          ELSE

               /* End date the existing record */
               hr_sit_api.update_sit
                            (p_validate                     => FALSE
                            ,p_person_analysis_id           => v_person_analysis_id
                            ,p_pea_object_version_number    => v_pea_object_version_number
                            ,p_analysis_criteria_id         => v_analysis_criteria_id
                            ,p_date_to                      => v_date_to
                            );
          END IF;

      END IF;

        /* Rehire - UPDATE_FISCAL_SIT' */

        v_analysis_criteria_id := NULL;

        hr_sit_api.create_sit
            (p_person_id                  =>  p_person_id,
             p_business_group_id          =>  p_business_group_id,
             p_id_flex_num                =>  v_id_flex_num,
             p_effective_date             =>  p_effective_date,
             p_date_from                  =>  p_effective_date,
             p_segment1                   =>  p_segment_1,
             p_segment2                   =>  p_segment_2,
             p_segment3                   =>  p_segment_3,
			 p_analysis_criteria_id       =>  v_analysis_criteria_id,
             p_person_analysis_id         =>  v_person_analysis_id,
             p_pea_object_version_number  =>  v_pea_object_version_number);

   EXCEPTION
      WHEN api_error
      THEN
         g_error_message    := 'Error at update UPDATE_FISCAL_SIT' || l_error_message;
         g_label2           := 'Employee Number';
         g_secondary_column :=  p_employee_number;
      WHEN OTHERS
      THEN
         g_error_message    := 'Other Error at update UPDATE_FISCAL_SIT' || SQLERRM;
         g_label2           := 'Employee Number';
         g_secondary_column := p_employee_number;

   END UPDATE_FISCAL_SIT;


/* 7.3.6 */
/******************************************************************

   Procedure Create Work Insurance
    -- Author: Christiane chan
    -- Date:  Nov 12,2020
    -- Parameters:
    -- Description: This procedure creates Work Insurance special information
    -- Modification Log
    -- Version    Developer              Date         Description
    -- ---        ----------------    -----------     --------------------------------
    -- 1.0        Christiane chan     Nov 12,2020     Initial Delivery through 7.3.6
    --
    -- Modification Log

    -- Version    Developer              Date         Description
    -- ---        ----------------    -----------     --------------------------------

*********************************************************************/

    PROCEDURE create_work_insurance(
                                p_business_group_id  IN  NUMBER,
                                p_person_id          IN  NUMBER,
                                p_effective_date     IN  DATE,
                                p_segment_1          IN  VARCHAR2,
                                p_segment_2          IN  VARCHAR2
                              ) IS


    v_analysis_criteria_id      per_person_analyses.analysis_criteria_id%TYPE;
    v_person_analysis_id        per_person_analyses.person_analysis_id%TYPE;
    v_pea_object_version_number per_person_analyses.object_version_number%TYPE;
    v_id_flex   fnd_id_flex_structures_vl.id_flex_num%TYPE;

    l_success_flag              g_success_flag%TYPE;
    l_error_message             g_error_message%TYPE;
    l_segment1                  per_analysis_criteria.segment1%TYPE;
    l_segment2                  per_analysis_criteria.segment2%TYPE;


    CURSOR c_id_flex IS
    SELECT id_flex_num
    FROM fnd_id_flex_structures_vl
    WHERE  ID_FLEX_STRUCTURE_CODE = 'GRC_WORK_INSURENCE_DETAILS';

   BEGIN
      g_module_name := 'create_work_insurance';

       OPEN c_id_flex;
       FETCH c_id_flex INTO v_id_flex;
       CLOSE c_id_flex;

        hr_sit_api.create_sit
            (p_person_id                  =>  p_person_id,
             p_business_group_id          =>  p_business_group_id,
             p_id_flex_num                =>  v_id_flex,
             p_effective_date             =>  p_effective_date,
             p_date_from                  =>  p_effective_date,
             p_segment1                   =>  p_segment_1,
             p_segment2                   =>  p_segment_2,
             p_analysis_criteria_id       =>  v_analysis_criteria_id,
             p_person_analysis_id         =>  v_person_analysis_id,
             p_pea_object_version_number  =>  v_pea_object_version_number);

            l_success_flag := 'Y';

    EXCEPTION
    WHEN OTHERS
    THEN
        l_success_flag      := 'N';
        l_error_message     := SQLERRM;
        g_error_message     := 'Error others in Create Work Insurance' || SQLERRM;
        g_label2            := 'Person Id';
        g_secondary_column  := p_person_id;
        RAISE skip_record;
   END  create_work_insurance;

/******************************************************************

   Procedure update_work_insurance
    -- Author: Christiane chan
    -- Date:  Nov 12,2020
    -- Parameters:
    -- Description: This procedure updates Work Insurancespecial infomraiotn
    -- Modification Log
    -- Version    Developer              Date         Description
    -- ---        ----------------    -----------     --------------------------------
    -- 1.0        Christiane chan     Nov 12,2020     Initial Delivery through 7.3.6
    --
    -- Modification Log

    -- Version    Developer              Date         Description
    -- ---        ----------------    -----------     --------------------------------

*********************************************************************/
   PROCEDURE update_work_insurance ( p_business_group_id  IN  NUMBER,
                                     p_person_id          IN  NUMBER,
                                     p_employee_number    IN  VARCHAR2,
                                     p_effective_date     IN  DATE,
                                     p_segment_1          IN  VARCHAR2,
                                     p_segment_2          IN  VARCHAR2
                                      )
   IS
      l_success_flag    g_success_flag%TYPE;
      l_error_message   g_error_message%TYPE;

      v_date_to             date;
      v_previous_date_from         date;

      v_pea_object_version_number     NUMBER;
      v_id_flex_num                   fnd_id_flex_structures_vl.id_flex_num%TYPE;
      v_person_analysis_id            per_person_analyses.person_analysis_id%TYPE;
      v_analysis_criteria_id          per_analysis_criteria.analysis_criteria_id%TYPE;

      CURSOR c_id_flex IS
      SELECT id_flex_num
      FROM fnd_id_flex_structures_vl
      WHERE  ID_FLEX_STRUCTURE_CODE = 'GRC_WORK_INSURENCE_DETAILS';


      CURSOR c_pre_contract IS
        SELECT  pa.person_analysis_id
                ,ac.ANALYSIS_CRITERIA_ID ,pa.date_from
                ,pa.object_version_number
          --START R12.2 Upgrade Remediation		
          /*FROM  hr.per_person_analyses pa,			-- Commented code by IXPRAVEEN-ARGANO,14-july-2023
                hr.per_analysis_criteria ac*/
		  FROM  apps.per_person_analyses pa,		--  code Added by IXPRAVEEN-ARGANO,   14-july-2023
                apps.per_analysis_criteria ac		
				--END R12.2.12 Upgrade remediation
         WHERE pa.analysis_criteria_id = ac.analysis_criteria_id
           AND pa.id_flex_num = v_id_flex_num
           AND pa.person_id = p_person_id
           AND date_from = (SELECT MAX(pa1.date_from)
                            --FROM  hr.per_person_analyses pa1			-- Commented code by IXPRAVEEN-ARGANO,14-july-2023
                            FROM  hr.per_person_analyses pa1            --  code Added by IXPRAVEEN-ARGANO,   14-july-2023
                            where pa1.id_flex_num = v_id_flex_num
                            AND pa1.person_id = p_person_id);

   BEGIN
      g_module_name := 'update_work_insurance';

       OPEN c_id_flex;
       FETCH c_id_flex INTO v_id_flex_num;
       CLOSE c_id_flex;

       OPEN c_pre_contract;
       FETCH c_pre_contract INTO v_person_analysis_id,v_analysis_criteria_id,v_previous_date_from
             ,v_pea_object_version_number;
       CLOSE c_pre_contract;

Fnd_File.put_line(Fnd_File.LOG, 'v_person_analysis_id'||v_person_analysis_id);--added by CC
      IF v_person_analysis_id IS NOT NULL THEN


          v_date_to := p_effective_date - 1;

Fnd_File.put_line(Fnd_File.LOG, '         p_effective_date->'||p_effective_date);--added by CC
Fnd_File.put_line(Fnd_File.LOG, 'v_previous_date_from->'||v_previous_date_from);--added by CC
Fnd_File.put_line(Fnd_File.LOG, '                       v_date_to->'||v_date_to);--added by CC

          IF v_previous_date_from >= v_date_to THEN

              /* FORCED TO End date the existing record with the day before current effective date*/
             Fnd_File.put_line(Fnd_File.LOG, 'hr_sit_api.update_sit THEN');--added by CC
              hr_sit_api.update_sit
                        (p_validate                     => FALSE
                        ,p_person_analysis_id           => v_person_analysis_id
                        ,p_pea_object_version_number    => v_pea_object_version_number
                        ,p_analysis_criteria_id         => v_analysis_criteria_id
                        ,p_date_from                    => v_date_to
                        ,p_date_to                      => v_date_to
                        );


          ELSE

             Fnd_File.put_line(Fnd_File.LOG, 'hr_sit_api.update_sit ELSE');--added by CC
               /* End date the existing record */
               hr_sit_api.update_sit
                            (p_validate                     => FALSE
                            ,p_person_analysis_id           => v_person_analysis_id
                            ,p_pea_object_version_number    => v_pea_object_version_number
                            ,p_analysis_criteria_id         => v_analysis_criteria_id
                            ,p_date_to                      => v_date_to
                            );
          END IF;

      END IF;

        /* Rehire - Create hireIQ' */

        v_analysis_criteria_id := NULL;

Fnd_File.put_line(Fnd_File.LOG, 'hhr_sit_api.create_sit CURRENT');--added by CC
Fnd_File.put_line(Fnd_File.LOG, '         p_effective_date->'||p_effective_date);--added by CC
        hr_sit_api.create_sit
            (p_person_id                  =>  p_person_id,
             p_business_group_id          =>  p_business_group_id,
             p_id_flex_num                =>  v_id_flex_num,
             p_effective_date             =>  p_effective_date,
             p_date_from                  =>  p_effective_date,
             p_segment1                   =>  p_segment_1,
             p_segment2                   =>  p_segment_2,
             p_analysis_criteria_id       =>  v_analysis_criteria_id,
             p_person_analysis_id         =>  v_person_analysis_id,
             p_pea_object_version_number  =>  v_pea_object_version_number);

   EXCEPTION
      WHEN api_error
      THEN
         g_error_message    := 'Error at update Work Insuranceapi' || l_error_message;
         g_label2           := 'Employee Number';
         g_secondary_column := p_employee_number;
         Fnd_File.put_line(Fnd_File.LOG, 'Error at update Work Insuranceapi'||DBMS_UTILITY.FORMAT_ERROR_STACK );
         RAISE skip_record;
      WHEN OTHERS
      THEN
         g_error_message    := 'Other Error at update Work Insuranceapi' || SQLERRM;
         g_label2           := 'Employee Number';
         g_secondary_column := p_employee_number;
         Fnd_File.put_line(Fnd_File.LOG, 'Error at update Work Insuranceapi'||DBMS_UTILITY.FORMAT_ERROR_STACK );
         RAISE skip_record;
   END update_work_insurance;
/* 7.3.6 */
/* 7.3.7 */
/******************************************************************

   Procedure Create_grc_tax_auth_dept_DOY
    -- Author: Christiane chan
    -- Date:  Nov 12,2020
    -- Parameters:
    -- Description: This procedure creates Work Insurance special information
    -- Modification Log
    -- Version    Developer              Date         Description
    -- ---        ----------------    -----------     --------------------------------
    -- 1.0        Christiane chan     Nov 12,2020     Initial Delivery through 7.3.7
    --
    -- Modification Log

    -- Version    Developer              Date         Description
    -- ---        ----------------    -----------     --------------------------------

*********************************************************************/

    PROCEDURE create_grc_tax_auth_dept_DOY(
                                p_business_group_id  IN  NUMBER,
                                p_person_id          IN  NUMBER,
                                p_effective_date     IN  DATE,
                                p_segment_1          IN  VARCHAR2
                              ) IS


    v_analysis_criteria_id      per_person_analyses.analysis_criteria_id%TYPE;
    v_person_analysis_id        per_person_analyses.person_analysis_id%TYPE;
    v_pea_object_version_number per_person_analyses.object_version_number%TYPE;
    v_id_flex   fnd_id_flex_structures_vl.id_flex_num%TYPE;

    l_success_flag              g_success_flag%TYPE;
    l_error_message             g_error_message%TYPE;
    l_segment1                  per_analysis_criteria.segment1%TYPE;

    CURSOR c_id_flex IS
    SELECT id_flex_num
    FROM fnd_id_flex_structures_vl
    WHERE  ID_FLEX_STRUCTURE_CODE = 'GRC_TAX_AUTHORITY_DEPT';

   BEGIN
      g_module_name := 'create_grc_tax_auth_dept_DOY';

       OPEN c_id_flex;
       FETCH c_id_flex INTO v_id_flex;
       CLOSE c_id_flex;

        hr_sit_api.create_sit
            (p_person_id                  =>  p_person_id,
             p_business_group_id          =>  p_business_group_id,
             p_id_flex_num                =>  v_id_flex,
             p_effective_date             =>  p_effective_date,
             p_date_from                  =>  p_effective_date,
             p_segment1                   =>  p_segment_1,
             p_analysis_criteria_id       =>  v_analysis_criteria_id,
             p_person_analysis_id         =>  v_person_analysis_id,
             p_pea_object_version_number  =>  v_pea_object_version_number);

            l_success_flag := 'Y';

    EXCEPTION
    WHEN OTHERS
    THEN
        l_success_flag      := 'N';
        l_error_message     := SQLERRM;
        g_error_message     := 'Error others in Create Work Insurance' || SQLERRM;
        g_label2            := 'Person Id';
        g_secondary_column  := p_person_id;
        RAISE skip_record;
   END  create_grc_tax_auth_dept_DOY;

/******************************************************************

   Procedure update_grc_tax_auth_dept_DOY
    -- Author: Christiane chan
    -- Date:  Nov 12,2020
    -- Parameters:
    -- Description: This procedure updates Work Insurancespecial infomraiotn
    -- Modification Log
    -- Version    Developer              Date         Description
    -- ---        ----------------    -----------     --------------------------------
    -- 1.0        Christiane chan     Nov 12,2020     Initial Delivery through 7.3.7
    --
    -- Modification Log

    -- Version    Developer              Date         Description
    -- ---        ----------------    -----------     --------------------------------

*********************************************************************/
   PROCEDURE update_grc_tax_auth_dept_DOY ( p_business_group_id  IN  NUMBER,
                                     p_person_id          IN  NUMBER,
                                     p_employee_number    IN  VARCHAR2,
                                     p_effective_date     IN  DATE,
                                     p_segment_1          IN  VARCHAR2
                                      )
   IS
      l_success_flag    g_success_flag%TYPE;
      l_error_message   g_error_message%TYPE;

      v_date_to             date;
      v_previous_date_from         date;

      v_pea_object_version_number     NUMBER;
      v_id_flex_num                   fnd_id_flex_structures_vl.id_flex_num%TYPE;
      v_person_analysis_id            per_person_analyses.person_analysis_id%TYPE;
      v_analysis_criteria_id          per_analysis_criteria.analysis_criteria_id%TYPE;

      CURSOR c_id_flex IS
      SELECT id_flex_num
      FROM fnd_id_flex_structures_vl
      WHERE  ID_FLEX_STRUCTURE_CODE = 'GRC_TAX_AUTHORITY_DEPT';


      CURSOR c_pre_contract IS
        SELECT  pa.person_analysis_id
                ,ac.ANALYSIS_CRITERIA_ID ,pa.date_from
                ,pa.object_version_number
          --START R12.2 Upgrade Remediation		
          /*FROM  hr.per_person_analyses pa,			-- Commented code by IXPRAVEEN-ARGANO,14-july-2023
                hr.per_analysis_criteria ac*/
		  FROM  apps.per_person_analyses pa,		--  code Added by IXPRAVEEN-ARGANO,   14-july-2023
                apps.per_analysis_criteria ac		
				--END R12.2.12 Upgrade remediation
         WHERE pa.analysis_criteria_id = ac.analysis_criteria_id
           AND pa.id_flex_num = v_id_flex_num
           AND pa.person_id = p_person_id
           AND date_from = (SELECT MAX(pa1.date_from)
                            --FROM  hr.per_person_analyses pa1			-- Commented code by IXPRAVEEN-ARGANO,14-july-2023
                            FROM  hr.per_person_analyses pa1            --  code Added by IXPRAVEEN-ARGANO,   14-july-2023
                            where pa1.id_flex_num = v_id_flex_num
                            AND pa1.person_id = p_person_id);

   BEGIN
      g_module_name := 'update_grc_tax_auth_dept_DOY';

       OPEN c_id_flex;
       FETCH c_id_flex INTO v_id_flex_num;
       CLOSE c_id_flex;

       OPEN c_pre_contract;
       FETCH c_pre_contract INTO v_person_analysis_id,v_analysis_criteria_id,v_previous_date_from
             ,v_pea_object_version_number;
       CLOSE c_pre_contract;


      IF v_person_analysis_id IS NOT NULL THEN


          v_date_to := p_effective_date - 1;

          IF v_previous_date_from >= v_date_to THEN

              /* FORCED TO End date the existing record with the day before current effective date*/

              hr_sit_api.update_sit
                        (p_validate                     => FALSE
                        ,p_person_analysis_id           => v_person_analysis_id
                        ,p_pea_object_version_number    => v_pea_object_version_number
                        ,p_analysis_criteria_id         => v_analysis_criteria_id
                        ,p_date_from                    => v_date_to
                        ,p_date_to                      => v_date_to
                        );


          ELSE

               /* End date the existing record */
               hr_sit_api.update_sit
                            (p_validate                     => FALSE
                            ,p_person_analysis_id           => v_person_analysis_id
                            ,p_pea_object_version_number    => v_pea_object_version_number
                            ,p_analysis_criteria_id         => v_analysis_criteria_id
                            ,p_date_to                      => v_date_to
                            );
          END IF;

      END IF;

        /* Rehire - Create hireIQ' */

        v_analysis_criteria_id := NULL;

        hr_sit_api.create_sit
            (p_person_id                  =>  p_person_id,
             p_business_group_id          =>  p_business_group_id,
             p_id_flex_num                =>  v_id_flex_num,
             p_effective_date             =>  p_effective_date,
             p_date_from                  =>  p_effective_date,
             p_segment1                   =>  p_segment_1,
             p_analysis_criteria_id       =>  v_analysis_criteria_id,
             p_person_analysis_id         =>  v_person_analysis_id,
             p_pea_object_version_number  =>  v_pea_object_version_number);

   EXCEPTION
      WHEN api_error
      THEN
         g_error_message    := 'Error at Update Tax Auth Dept api' || l_error_message;
         g_label2           := 'Employee Number';
         g_secondary_column := p_employee_number;
         RAISE skip_record;
      WHEN OTHERS
      THEN
         g_error_message    := 'Other Error at Update Tax Auth Dept apii' || SQLERRM;
         g_label2           := 'Employee Number';
         g_secondary_column := p_employee_number;
         RAISE skip_record;
   END update_grc_tax_auth_dept_DOY;


/* 7.3.7 */
    /*************************************************************************************************************
    -- PROCEDURE update_assignment
    -- Author: Ibrahim Konak
    -- Date:  Feb 26 2007
    -- Parameters:
    -- Description: PROCEDURE updates assignment record of the employee.
    -- Assignment was already created by the create employee procedure.
    -- Modification Log

    -- Version    Developer              Date         Description
    -- ---        ----------------    -----------     --------------------------------
    -- 1.4        MLagostena          Jan 23 2008     Added South Africa to the Integration.
    -- 1.5        MLagostena          Jan 26 2009     Added Argentina to the Integration.
    -- 1.6.1      NMondada            Mar 30 2009     Added Mexico to the Integration.
    -- 1.6.4      MLagostena          Jun 18 2009     Added specific format to date field contract_start_date for MEXICO in update_assignment procedure (TT#1196963)
    **************************************************************************************************************/
    PROCEDURE update_assignment (
          p_validate                        IN      BOOLEAN     DEFAULT FALSE,
      p_datetrack_mode                  IN      VARCHAR2,
      p_effective_date                  IN      DATE,
      p_assignment_id                   IN      NUMBER,
      p_business_group_id               IN      NUMBER,
      p_object_version_number           IN OUT  NUMBER,
      p_people_group1                   IN      VARCHAR2    DEFAULT NULL,
      p_people_group_id                 IN      NUMBER      DEFAULT NULL,
      p_job_id                          IN      NUMBER      DEFAULT NULL,
      p_grade_id                        IN      NUMBER      DEFAULT NULL,
      p_payroll_id                      IN      NUMBER      DEFAULT NULL,
      p_location_id                     IN      NUMBER,
      p_organization_id                 IN      NUMBER      DEFAULT NULL,
      p_pay_basis_id                    IN      NUMBER,
      p_employment_category             IN      VARCHAR2    DEFAULT NULL,
      p_supervisor_id                   IN      NUMBER      DEFAULT NULL,
      p_tax_unit_id                     IN      NUMBER,
      p_timecard_required               IN      VARCHAR2    DEFAULT NULL,
      p_work_schedule                   IN      VARCHAR2    DEFAULT NULL,
      p_frequency                       IN      VARCHAR2    DEFAULT NULL,
      p_normal_hours                    IN      VARCHAR2    DEFAULT NULL,
      p_set_of_books_id                 IN      NUMBER      DEFAULT NULL,
      p_expense_account_id              IN      NUMBER      DEFAULT NULL,
      p_ass_attribute_category          IN      VARCHAR2    DEFAULT NULL,
      p_night_diff_rate                 IN      NUMBER      DEFAULT NULL,
      p_attribute6                      IN      VARCHAR2    DEFAULT NULL,
      p_probation_period                IN      VARCHAR2    DEFAULT NULL,
      p_probation_unit                  IN      VARCHAR2    DEFAULT NULL,
      p_date_probation_end              IN      VARCHAR2    DEFAULT NULL,
      p_work_at_home                    IN      VARCHAR2    DEFAULT NULL,
      p_employee_category               IN      VARCHAR2    DEFAULT NULL,
      p_sal_review_period               IN      VARCHAR2    DEFAULT NULL,
      p_sal_review_period_frequency     IN      VARCHAR2    DEFAULT NULL,
      p_perf_review_period              IN      VARCHAR2    DEFAULT NULL,
      p_perf_review_period_frequency    IN      VARCHAR2    DEFAULT NULL,
      /* Version 1.3 - ZA Integration */
      p_education_level                 IN      VARCHAR2    DEFAULT NULL,
      p_ethnicity                       IN      VARCHAR2    DEFAULT NULL,
      p_nationality                     IN      VARCHAR2    DEFAULT NULL,
      /* Version 1.5 - ARG Integration */
      p_industry                        IN      VARCHAR2    DEFAULT NULL,
      p_unionaffiliation                IN      VARCHAR2    DEFAULT NULL,
      /* Version 1.6.1 - MEX Integration */
      p_ss_salary_type                  IN      VARCHAR2    DEFAULT NULL,
      p_shift_id                        IN      VARCHAR2    DEFAULT NULL,
      p_contract_start_dt               IN      DATE, /*Version 1.6.4*/
      p_contract_type                   IN      VARCHAR2    DEFAULT NULL,
      p_employee_type                   IN      VARCHAR2    DEFAULT NULL,
       /* Version 1.7 - Costa Rica Integration*/
      p_LanguageDifferential            IN      VARCHAR2    DEFAULT NULL,
      p_ANNUALTENUREPAY                 IN      VARCHAR2    DEFAULT NULL, /* 7.0 */
      p_WORK_ARRANGEMENT                IN      VARCHAR2    DEFAULT NULL, /* 7.2 */
      p_WORK_ARRANGEMENT_REASON         IN      VARCHAR2    DEFAULT NULL  /* 7.2 */
     ,P_BULG_EMP_CODE                   IN      VARCHAR2    DEFAULT NULL,
	  P_TECH_SOLN                       IN      VARCHAR2    DEFAULT NULL,	-- Added for 7.9
      P_AUS_ADDL_ASG_DETL               IN      VARCHAR2    DEFAULT NULL,   -- Added for 8.6
	  P_AUS_JOB                         IN      VARCHAR2    DEFAULT NULL,   -- Added for 8.6
	  P_MEX_SODEXO_LOC                  IN      VARCHAR2    DEFAULT NULL    -- Added for 8.7
      -- Output parameters

    ) IS
      l_success_flag                    g_success_flag%TYPE;
      l_error_message                   g_error_message%TYPE;
      l_frequency                       VARCHAR2 (60);
      l_timecard_required               hr_soft_coding_keyflex.segment3%TYPE;
      l_work_schedule                   hr_soft_coding_keyflex.segment4%TYPE;
      l_segment2                        hr_soft_coding_keyflex.segment2%TYPE;
      l_segment5                        hr_soft_coding_keyflex.segment5%TYPE;
      l_segment6                        hr_soft_coding_keyflex.segment6%TYPE;
      l_segment8                        hr_soft_coding_keyflex.segment8%TYPE;   /* 6.2 */
      l_segment9                        hr_soft_coding_keyflex.segment9%TYPE;   /* 6.2 */
      l_segment10                       hr_soft_coding_keyflex.segment10%TYPE;  /* 6.2 */
      l_segment11                       hr_soft_coding_keyflex.segment11%TYPE;  /* 6.2 */
      l_people_group1                   pay_people_groups.segment1%TYPE;
      l_reason                          per_all_assignments_f.change_reason%TYPE;

      l_probation_period                per_all_assignments_f.probation_period%TYPE;
      l_probation_unit                  per_all_assignments_f.probation_unit%TYPE;
      l_date_probation_end              per_all_assignments_f.date_probation_end%TYPE;

      l_tax_unit_id                     hr_organization_units.organization_id%TYPE;
      l_grade_id                        per_all_assignments_f.grade_id%TYPE;
      l_object_version_number           per_all_assignments_f.object_version_number%TYPE;
      l_special_ceiling_step_id         per_all_assignments_f.special_ceiling_step_id%TYPE;
      l_group_name                      pay_people_groups.group_name%TYPE;
      l_effective_start_date            per_all_assignments_f.effective_start_date%TYPE;
      l_effective_end_date              per_all_assignments_f.effective_end_date%TYPE;
      l_people_group_id                 per_all_assignments_f.people_group_id%TYPE;
      l_employee_category               per_all_assignments_f.employee_category%TYPE;
      l_sal_review_period               per_all_assignments_f.sal_review_period%TYPE;
      l_sal_review_period_frequency     per_all_assignments_f.sal_review_period_frequency%TYPE;
      l_perf_review_period              per_all_assignments_f.perf_review_period%TYPE;
      l_perf_review_period_frequency    per_all_assignments_f.perf_review_period_frequency%TYPE;
      l_org_now_no_manager_warning      BOOLEAN;
      l_other_manager_warning           BOOLEAN;
      l_spp_delete_warning              BOOLEAN;
      l_entries_changed_warning         VARCHAR2 (80);
      l_tax_district_changed_warning    BOOLEAN;
      l_concatenated_segments           hr_soft_coding_keyflex.concatenated_segments%TYPE;
      l_soft_coding_keyflex_id          hr_soft_coding_keyflex.soft_coding_keyflex_id%TYPE;
      l_comment_id                      per_all_assignments_f.comment_id%TYPE;
      l_no_managers_warning             BOOLEAN;
      l_cagr_grade_def_id               NUMBER;
      l_cagr_concatenated_segments      VARCHAR2(280);
      l_hourly_salaried_warning         BOOLEAN;
      l_gsp_post_process_warning        VARCHAR2(280);
      /* Version 1.4 - ZA Integration */
      l_attribute9                      per_all_assignments_f.ASS_ATTRIBUTE9%TYPE;
      l_attribute10                     per_all_assignments_f.ASS_ATTRIBUTE10%TYPE;
      l_attribute11                     per_all_assignments_f.ASS_ATTRIBUTE11%TYPE;
      /* Version 1.6.1 - MEX Integration */
      l_attribute7                      per_all_assignments_f.ass_attribute7%TYPE;
      l_attribute13                     per_all_assignments_f.ass_attribute13%TYPE;
      l_attribute15                     per_all_assignments_f.ASS_ATTRIBUTE15%TYPE;
      l_attribute14                     per_all_assignments_f.ASS_ATTRIBUTE14%TYPE; /* 3.5.4 MEX - Contract Start Date*/
      /* Version 1.7 - CR Integration */
      l_attribute8                      per_all_assignments_f.ASS_ATTRIBUTE8%TYPE;
      l_attribute20                     per_all_assignments_f.ASS_ATTRIBUTE20%TYPE; /* 7.0 */
      l_attribute22                     per_all_assignments_f.ASS_ATTRIBUTE22%TYPE; /* 7.2 */
      l_attribute23                     per_all_assignments_f.ASS_ATTRIBUTE23%TYPE; /* 7.2 */
      l_assginment_cat                  VARCHAR2(40);
      l_emplt_cat                   VARCHAR2(40);
      l_len                             NUMBER;
      L_BULG_EMP_CODE VARCHAR2(100):=NULL;
	  l_attribute24                     PER_ALL_ASSIGNMENTS_F.ASS_ATTRIBUTE24%TYPE; -- Added as part of 7.9

      l_attribute2                      per_all_assignments_f.ASS_ATTRIBUTE2%TYPE;  -- Added for 8.6
      l_attribute3                      per_all_assignments_f.ASS_ATTRIBUTE3%TYPE;  -- Added for 8.6
	  l_attribute16                     PER_ALL_ASSIGNMENTS_F.ASS_ATTRIBUTE16%TYPE; -- Added as part of 8.7

   BEGIN
      g_module_name := 'update_assignment';

      l_object_version_number           := p_object_version_number;
      l_tax_unit_id                     := p_tax_unit_id;
      l_grade_id                        := p_grade_id;

      l_people_group_id                 := NULL;
      l_probation_period                := NULL;
      l_probation_unit                  := NULL;
      l_date_probation_end              := NULL;
      l_timecard_required               := p_timecard_required;
      l_work_schedule                   := p_work_schedule;
      l_employee_category               := NULL;
      l_sal_review_period               := NULL;
      l_sal_review_period_frequency     := NULL;
      l_perf_review_period              := NULL;
      l_perf_review_period_frequency    := NULL;

      /* Version 1.4 - 1.5 - ZA- ARG Integrations */
      l_attribute9                      := NULL;
      l_attribute11                     := NULL;
      l_attribute10                     := NULL;

      /* Version 1.6.1 - MEX Integration */
      l_attribute7                      := NULL;
      l_segment2                        := NULL;        -- 8.6
      l_segment5                        := NULL;
      l_segment6                        := NULL;
      l_attribute13                     := NULL;   -- Employee Type
      l_attribute15                     := NULL;   -- reserved for Mexico
      l_attribute14                     := NULL;    /* 3.5.4 MEX - Contract Start Date*/
      l_attribute22                     := p_WORK_ARRANGEMENT;         /* 7.2 */
      l_attribute23                     := p_WORK_ARRANGEMENT_REASON; /* 7.2 */
	  l_attribute24                     := p_tech_soln;         -- Added as part of 7.9
	  l_attribute16                     := P_MEX_SODEXO_LOC; -- Added as part of 8.7


      /* Version 6.2  Motif India Integration -- Enabling Salary */

      l_segment8                    := NULL;    -- Covered by Gratuity Act default to 'No'
      l_segment9                    := NULL;    -- Substantial Interest in Company default to 'No'
      l_segment10                   := NULL;    -- Director default to 'No'
      l_segment11                   := NULL;    -- Specified Employee default to 'Yes'

      /* Version 1.7 - CR Integrations */
      l_attribute8                      := NULL;
      l_emplt_cat := p_employment_category;
      l_attribute20                     := NULL; /* 7.0 */
      L_BULG_EMP_CODE:= P_BULG_EMP_CODE;

      IF p_business_group_id = 325 -- US
      THEN
         l_people_group_id := p_people_group_id;

      ELSIF p_business_group_id = 1517  -- PHL
      THEN
            l_probation_period              := p_probation_period;
            l_probation_unit                := p_probation_unit;
            l_date_probation_end            := TO_DATE(p_date_probation_end,'MM/DD/RRRR');
            l_timecard_required             := NULL;
            l_work_schedule                 := NULL;
            l_segment5                      := 'S';
            l_segment6                      := 'Semi-Month';
            l_attribute7                    := LTRIM(RTRIM(p_night_diff_rate));

      ELSIF p_business_group_id = 1761  -- UK
      THEN
            l_probation_period              := p_probation_period;
            l_probation_unit                := p_probation_unit;
            l_date_probation_end            := TO_DATE(p_date_probation_end,'MM/DD/RRRR');
            l_employee_category             := p_employee_category;
            l_sal_review_period             := p_sal_review_period;
            l_sal_review_period_frequency   := p_sal_review_period_frequency;
            l_perf_review_period            := p_perf_review_period;
            l_perf_review_period_frequency  := p_perf_review_period_frequency;
            l_tax_unit_id                   := NULL;
            l_timecard_required             := NULL;
            l_work_schedule                 := NULL;
            l_grade_id                      := NULL;

     ELSIF p_business_group_id = 1631  THEN -- Brz
            l_probation_period              := p_probation_period;
            l_probation_unit                := p_probation_unit;
            l_date_probation_end            := TO_DATE(p_date_probation_end,'MM/DD/RRRR');
            l_work_schedule                   := p_shift_id;

--8.6-Begin AU
	  ELSIF p_business_group_id = 1839  THEN
            l_segment2                      := 'N';                   --Leave Loading Flag
            l_timecard_required             := NULL;
            l_attribute2                    := P_AUS_ADDL_ASG_DETL;   --Additional ASG details
            l_attribute3                    := P_AUS_JOB;             --AUS Job
--8.6-End

      ELSIF apps.ttec_get_bg (p_business_group_id, p_organization_id) = 6536 /* Version 1.3 - ZA Integration */
      THEN
            l_attribute9                    := p_education_level;    -- Education_level
            --l_attribute10                   := p_ethnicity;		-- Commented for 8.4
            --l_attribute11                   := p_nationality;        -- Nationality    8.8
            l_work_schedule                 := NULL;
            l_probation_period              := p_probation_period;
            l_probation_unit                := p_probation_unit;

      ELSIF p_business_group_id = 1632  /* Version 1.4 - ARG Integration */
      THEN
         l_attribute9                       := p_industry;          -- Tipo de actividad laboral (INDUSTRY)
         l_attribute11                      := p_unionaffiliation;  -- Union Affiliation (CONVENIO)
         l_probation_period                 := p_probation_period;
         l_probation_unit                   := p_probation_unit;
         l_timecard_required                := NULL;

      ELSIF p_business_group_id = 1633 /* Version 1.6.1 - MEX Integration */
      THEN
         l_attribute10                      := TO_CHAR(p_contract_start_dt,'YYYY/MM/DD HH:MI:SS'); /*Version 1.6.4*/
         l_attribute11                      := p_contract_type;
         l_segment6                         := p_ss_salary_type;      -- Social Security Salary Type
         l_attribute7                       := p_shift_id;
         l_attribute13                      := p_employee_type;
         l_employee_category                := p_employee_category;
         l_probation_period                 := p_probation_period;
         l_probation_unit                   := p_probation_unit;
         -- begin v2.4    employment category
         l_len := instr(p_employment_category, '|');
         l_emplt_cat := SUBSTR ( p_employment_category,  1,  l_len -1);
         l_attribute15  := SUBSTR (p_employment_category, l_len + 1);
         l_attribute14  := TO_CHAR(p_contract_start_dt,'YYYY/MM/DD HH:MI:SS');/* 3.5.4 MEX - Contract Start Date */

      ELSIF p_business_group_id = 48558 /* Version 6.2  Motif India Integration -- Adding Salary */
      THEN
            l_segment8                    := 'N';    -- Covered by Gratuity Act default to 'No'
            l_segment9                    := 'N';    -- Substantial Interest in Company default to 'No'
            l_segment10                   := 'N';    -- Director default to 'No'
            l_segment11                   := 'Y';    -- Specified Employee default to 'Yes'

      ELSIF p_business_group_id = 5054 AND apps.ttec_get_bg (p_business_group_id, p_organization_id) != 6536 /* 7.0 */
      THEN

         l_attribute20        := p_ANNUALTENUREPAY; /* 7.0 */
      --   p_attribute6 := P_BULG_EMP_CODE;

         IF apps.ttec_get_bg (p_business_group_id, p_organization_id) = 5075 /* Version 1.7 - CR Integration */ /* 7.0 */
         THEN

             l_attribute7     := p_shift_id;
             l_attribute8     := p_LanguageDifferential;

         END IF;

      END IF;

      IF g_action_type = 'REHIRE'
      THEN
         IF p_business_group_id in (1761 ,1631    -- UK --- 2.6 BRZ Ingegration added 1631
                                   ,48558  --5.0 Motif India Integration
                                   )
         THEN
            l_reason := NULL;

         ELSIF p_business_group_id = 1632 OR p_business_group_id = 1633/* Version 1.5 - ARG Integration */ /* Version 1.6.1 - MEX Integration */
         THEN

            l_reason := NULL;

         ELSIF p_business_group_id = 1839  THEN             -- Added for 8.6

            l_reason := NULL;

         ELSE

            l_reason := 'REH';

         END IF;

      ELSE -- NEW HIRE
         IF p_business_group_id =  1761   -- UK
         THEN

            l_reason := 'IDL';

         --ELSIF p_business_group_id = 1632 OR p_business_group_id = 1633 OR p_business_group_id = 1631  /* Version 1.5 - ARG Integration */ /* Version 1.6.1 - MEX Integration */  --- 2.6 BRZ Ingegration added 1631
         ELSIF p_business_group_id IN (    1632  /* Version 1.5 - ARG Integration */
                                         , 1633  /* Version 1.6.1 - MEX Integration */
                                         , 1631  /* Version 2.6 BRZ Ingegration added 1631 */
                                         , 48558 /* Version 6.0 Motif India Integration */
                                       )
         THEN

            l_reason := NULL;

        ELSIF p_business_group_id = 1839  THEN             -- Added for 8.6

            l_reason := NULL;

         ELSE
            l_reason := 'NEWH';

         END IF;

      END IF;

     -- DBMS_OUTPUT.PUT_LINE('reason:'||l_reason);


   BEGIN  --NORMAL HOURS, FREQUENCY, SUPERVISOR, GRE, PROBATION, WORK AT HOME
       l_grc_business_group_id:=NULL;
          DBMS_OUTPUT.PUT_LINE('frequency:'||p_frequency);
          DBMS_OUTPUT.PUT_LINE('probation period:'||p_probation_period);
          DBMS_OUTPUT.PUT_LINE('probation unit:'||p_probation_unit);
          DBMS_OUTPUT.PUT_LINE('location:'||p_location_id);
          DBMS_OUTPUT.PUT_LINE('payroll:'||p_payroll_id);
          DBMS_OUTPUT.PUT_LINE('tax unit:'||p_tax_unit_id);
          DBMS_OUTPUT.PUT_LINE('work schedule:'||l_work_schedule);
          DBMS_OUTPUT.PUT_LINE('organization:' || p_organization_id);
          DBMS_OUTPUT.PUT_LINE('job_id:'|| p_job_id);
          DBMS_OUTPUT.PUT_LINE('grade_id:'||p_grade_id );
          DBMS_OUTPUT.PUT_LINE('pay_basis_id:'||p_pay_basis_id);
          DBMS_OUTPUT.PUT_LINE('assignment_id:'||p_assignment_id);
          DBMS_OUTPUT.PUT_LINE('assignment ovn:'||l_object_version_number);

 --Fnd_File.put_line(Fnd_File.LOG, 'Error api assignment update:'||DBMS_UTILITY.FORMAT_ERROR_STACK );
          Fnd_File.put_line(Fnd_File.LOG,'frequency:'||p_frequency);
          Fnd_File.put_line(Fnd_File.LOG,'probation period:'||p_probation_period);
          Fnd_File.put_line(Fnd_File.LOG,'probation unit:'||p_probation_unit);
          Fnd_File.put_line(Fnd_File.LOG,'location:'||p_location_id);
          Fnd_File.put_line(Fnd_File.LOG,'payroll:'||p_payroll_id);
          Fnd_File.put_line(Fnd_File.LOG,'tax unit:'||p_tax_unit_id);
          Fnd_File.put_line(Fnd_File.LOG,'work schedule:'||l_work_schedule);
          Fnd_File.put_line(Fnd_File.LOG,'organization:' || p_organization_id);
          Fnd_File.put_line(Fnd_File.LOG,'job_id:'|| p_job_id);
          Fnd_File.put_line(Fnd_File.LOG,'grade_id:'||p_grade_id );
          Fnd_File.put_line(Fnd_File.LOG,'pay_basis_id:'||p_pay_basis_id);
          Fnd_File.put_line(Fnd_File.LOG,'assignment_id:'||p_assignment_id);
          Fnd_File.put_line(Fnd_File.LOG,'assignment ovn:'||l_object_version_number);


          Fnd_File.put_line(Fnd_File.LOG,'l_attribute13:'||l_attribute13);
          Fnd_File.put_line(Fnd_File.LOG,'l_attribute14:'||l_attribute14);
          Fnd_File.put_line(Fnd_File.LOG,'reason:'||l_reason);


        --   Fnd_File.put_line(Fnd_File.LOG,'p_validate:'||p_validate);
 Fnd_File.put_line(Fnd_File.LOG,'p_effective_date:'||p_effective_date);
 Fnd_File.put_line(Fnd_File.LOG,'p_datetrack_mode:'||p_datetrack_mode);
 Fnd_File.put_line(Fnd_File.LOG,'p_assignment_id:'||p_assignment_id);
 Fnd_File.put_line(Fnd_File.LOG,'l_object_version_number:'||l_object_version_number);
 Fnd_File.put_line(Fnd_File.LOG,'p_supervisor_id:'||p_supervisor_id);
 Fnd_File.put_line(Fnd_File.LOG,'p_expense_account_id:'||p_expense_account_id);
 Fnd_File.put_line(Fnd_File.LOG,'p_set_of_books_id:'||p_set_of_books_id);
 Fnd_File.put_line(Fnd_File.LOG,'p_normal_hours:'||p_normal_hours);
 Fnd_File.put_line(Fnd_File.LOG,'p_business_group_id:'||p_business_group_id);
  --Fnd_File.put_line(Fnd_File.LOG,'p_validate:'||to_char(p_validate));

  Fnd_File.put_line(Fnd_File.LOG,'p_attribute6:'||p_attribute6);
  Fnd_File.put_line(Fnd_File.LOG,'l_attribute2:'||l_attribute2);        -- Added for 8.6
  Fnd_File.put_line(Fnd_File.LOG,'l_attribute3:'||l_attribute3);        -- Added for 8.6
  Fnd_File.put_line(Fnd_File.LOG,'l_attribute7:'||l_attribute7);
  Fnd_File.put_line(Fnd_File.LOG,'l_attribute8:'||l_attribute8);
  Fnd_File.put_line(Fnd_File.LOG,'l_attribute9:'||l_attribute9);
  Fnd_File.put_line(Fnd_File.LOG,'l_attribute10:'||l_attribute10);
  Fnd_File.put_line(Fnd_File.LOG,'l_attribute11:'||l_attribute11);
  Fnd_File.put_line(Fnd_File.LOG,'l_attribute15:'||l_attribute15);
  Fnd_File.put_line(Fnd_File.LOG,'l_attribute20:'||l_attribute20);
  Fnd_File.put_line(Fnd_File.LOG,'l_attribute22:'||l_attribute22);

  Fnd_File.put_line(Fnd_File.LOG,'l_attribute23:'||l_attribute23);
  Fnd_File.put_line(Fnd_File.LOG,'l_tax_unit_id:'||l_tax_unit_id);
  Fnd_File.put_line(Fnd_File.LOG,'l_timecard_required:'||l_timecard_required);
  Fnd_File.put_line(Fnd_File.LOG,'l_work_schedule:'||l_work_schedule);
  Fnd_File.put_line(Fnd_File.LOG,'l_segment2:'||l_segment2);
  Fnd_File.put_line(Fnd_File.LOG,'l_segment5:'||l_segment5);
  Fnd_File.put_line(Fnd_File.LOG,'l_segment6:'||l_segment6);

  Fnd_File.put_line(Fnd_File.LOG,'l_segment8:'||l_segment8);
  Fnd_File.put_line(Fnd_File.LOG,'l_segment9:'||l_segment9);
  Fnd_File.put_line(Fnd_File.LOG,'l_segment10:'||l_segment10);
  Fnd_File.put_line(Fnd_File.LOG,'l_segment11:'||l_segment11);


  Fnd_File.put_line(Fnd_File.LOG,'l_probation_period:'||l_probation_period);
  Fnd_File.put_line(Fnd_File.LOG,'l_probation_unit:'||l_probation_unit);

    Fnd_File.put_line(Fnd_File.LOG,'l_date_probation_end:'||l_date_probation_end);
    Fnd_File.put_line(Fnd_File.LOG,'p_work_at_home:'||p_work_at_home);

        Fnd_File.put_line(Fnd_File.LOG,'l_employee_category:'||l_employee_category);
        Fnd_File.put_line(Fnd_File.LOG,'l_sal_review_period:'||l_sal_review_period);

        Fnd_File.put_line(Fnd_File.LOG,'l_sal_review_period_frequency:'||l_sal_review_period_frequency);
        Fnd_File.put_line(Fnd_File.LOG,'l_perf_review_period:'||l_perf_review_period);

        Fnd_File.put_line(Fnd_File.LOG,'l_perf_review_period_frequency:'||l_perf_review_period_frequency);

/* 7.3 Changes for Greece Integration */
    IF p_business_group_id = 54749
    THEN
    l_grc_business_group_id:=NULL;
    ELSE
    l_grc_business_group_id:=p_business_group_id;
    END IF;
/* 7.3 Changes for Greece Integration */

          Hr_Assignment_Api.update_emp_asg
                   (p_validate                      => p_validate,
                    p_effective_date                => p_effective_date,
                    p_datetrack_update_mode         => p_datetrack_mode,
                    p_change_reason                 => l_reason,
                    p_assignment_id                 => p_assignment_id,
                    p_object_version_number         => l_object_version_number,
                    p_supervisor_id                 => p_supervisor_id,
                    p_default_code_comb_id          => p_expense_account_id,
                    p_set_of_books_id               => p_set_of_books_id,
                    p_frequency                     => p_frequency,
                    p_normal_hours                  => p_normal_hours,
                    p_ass_attribute_category        => l_grc_business_group_id, --p_ass_attribute_category,--7.3 Changes for Greece Integration
                    p_ass_attribute2                => l_attribute2,
                    p_ass_attribute3                => l_attribute3,
                    p_ass_attribute6                => NVL(p_attribute6,P_BULG_EMP_CODE), -- probation PHL
                    p_ass_attribute7                => l_attribute7,
                    /* Version 1.7 - CR Integration */
                    p_ass_attribute8                => l_attribute8,
                    /* Version 1.3 - ZA Integration */
                    p_ass_attribute9                => l_attribute9,
                    p_ass_attribute10               => l_attribute10,
                    p_ass_attribute11               => l_attribute11,
                    p_ass_attribute15               => l_attribute15,  -- v2.4
					p_ass_attribute16               => l_attribute16, -- Added as part of 8.7
                    p_ass_attribute20               => l_attribute20, /* 7.0 */
                    p_ass_attribute22               => l_attribute22, /* 7.2 */
                    p_ass_attribute23               => l_attribute23, /* 7.2 */
					p_ass_attribute24               => l_attribute24, -- Added as part of 7.9
                    --
                    p_segment1                      => l_tax_unit_id,
                    p_segment2                      => l_segment2,     -- 8.6
                    p_segment3                      => l_timecard_required,
                    p_segment4                      => l_work_schedule,
                    p_segment5                      => l_segment5,
                    p_segment6                      => l_segment6,
                    p_segment8                      => l_segment8,  /* 6.2 */
                    p_segment9                      => l_segment9,  /* 6.2 */
                    p_segment10                     => l_segment10, /* 6.2 */
                    p_segment11                     => l_segment11, /* 6.2 */
                    p_probation_period              => l_probation_period,
                    p_probation_unit                => l_probation_unit,
                    p_date_probation_end            => l_date_probation_end,
                    p_work_at_home                  => p_work_at_home,
                    p_employee_category             => l_employee_category,
                    p_sal_review_period             => l_sal_review_period,
                    p_sal_review_period_frequency   => l_sal_review_period_frequency,
                    p_perf_review_period            => l_perf_review_period,
                    p_perf_review_period_frequency  => l_perf_review_period_frequency,
                    /* Version 1.6.1 - MEX Integration */
                    p_ass_attribute13               => l_attribute13,
                    p_ass_attribute14               => l_attribute14, /* 3.5.4 MEX - Contract Start Date */
             --*** API OUT PARAMETERS ***--
                    p_concatenated_segments         => l_concatenated_segments,
                    p_soft_coding_keyflex_id        => l_soft_coding_keyflex_id,
                    p_comment_id                    => l_comment_id,
                    p_effective_start_date          => l_effective_start_date,
                    p_effective_end_date            => l_effective_end_date,
                    p_no_managers_warning           => l_no_managers_warning,
                    p_other_manager_warning         => l_other_manager_warning,
                    p_cagr_grade_def_id             => l_cagr_grade_def_id,
                    p_cagr_concatenated_segments    => l_cagr_concatenated_segments,
                    p_hourly_salaried_warning       => l_hourly_salaried_warning,
                    p_gsp_post_process_warning      => l_gsp_post_process_warning
                   );

        -- DBMS_OUTPUT.PUT_LINE('SCK:'||l_soft_coding_keyflex_id);
         Fnd_File.put_line(Fnd_File.LOG,'SCK:'||l_soft_coding_keyflex_id);

         l_success_flag := 'Y';
            Fnd_File.put_line(Fnd_File.LOG,'l_attribute13:'||l_attribute13);
          Fnd_File.put_line(Fnd_File.LOG,'l_attribute14:'||l_attribute14);
          Fnd_File.put_line(Fnd_File.LOG,'reason:'||l_reason);

      EXCEPTION
         WHEN OTHERS
         THEN
            l_success_flag  := 'N';
            l_error_message := SQLERRM;
            Fnd_File.put_line(Fnd_File.LOG, 'Error api assignment update:'||DBMS_UTILITY.FORMAT_ERROR_STACK );
      END;

      IF l_success_flag = 'Y'
      THEN
         DBMS_OUTPUT.PUT_LINE('employment category:'||p_employment_category);
         BEGIN -- JOB, GRADE, PAYROLL, LOCATION, ORGANIZATION, PAY BASIS
        --            print_line
        --               ('p_validate                          =>' || p_validate||
        --                'p_effective_date                    =>' || p_effective_date||
        --                'p_datetrack_update_mode             =>' || p_datetrack_mode||
        --                'p_assignment_id                     =>' || p_assignment_id||
        --                'p_object_version_number             =>' || l_object_version_number||
        --                'p_job_id                            =>' || p_job_id||
        --                'p_grade_id                          =>' || l_grade_id||
        --                'p_payroll_id                        =>' || p_payroll_id||
        --                'p_location_id                       =>' || p_location_id||
        --                'p_organization_id                   =>' || p_organization_id ||
        --                'p_pay_basis_id                      =>' || p_pay_basis_id||
        --                'p_employment_category               =>' || p_employment_category
        --               );

            Hr_Assignment_Api.update_emp_asg_criteria
               (p_validate                          => p_validate,
                p_effective_date                    => p_effective_date,
                p_datetrack_update_mode             => p_datetrack_mode,
                p_assignment_id                     => p_assignment_id,
                p_object_version_number             => l_object_version_number,
                p_job_id                            => p_job_id,
                p_grade_id                          => l_grade_id,
                p_payroll_id                        => p_payroll_id,
                p_location_id                       => p_location_id,
                p_organization_id                   => p_organization_id,
                p_pay_basis_id                      => p_pay_basis_id,
                p_employment_category               => l_emplt_cat,                       -- v2.4
                --*** API OUT PARAMETERS ***--
                p_special_ceiling_step_id           => l_special_ceiling_step_id,
                p_group_name                        => l_group_name,
                p_effective_start_date              => l_effective_start_date,
                p_effective_end_date                => l_effective_end_date,
                p_people_group_id                   => l_people_group_id,
                p_org_now_no_manager_warning        => l_org_now_no_manager_warning,
                p_other_manager_warning             => l_other_manager_warning,
                p_spp_delete_warning                => l_spp_delete_warning,
                p_entries_changed_warning           => l_entries_changed_warning,
                p_tax_district_changed_warning      => l_tax_district_changed_warning
               );

         EXCEPTION
            WHEN OTHERS
            THEN
               l_success_flag   := 'N';
               l_error_message  := SQLERRM;
               Fnd_File.put_line(Fnd_File.LOG, 'Error api assignment update:'||DBMS_UTILITY.FORMAT_ERROR_STACK );
         END;

      END IF;


      IF l_success_flag = 'N'
      THEN
         RAISE api_error;

      END IF;

      p_object_version_number := l_object_version_number;

   EXCEPTION
      WHEN api_error
      THEN
         --DBMS_OUTPUT.PUT_LINE ('Error api assignment update'|| l_error_message);
         g_error_message    := 'Error api assignment update' || l_error_message;
         g_label2           := 'Location';
         g_secondary_column := g_location_name;
         Fnd_File.put_line(Fnd_File.LOG, 'Error api assignment update:'||DBMS_UTILITY.FORMAT_ERROR_STACK );
         RAISE skip_record;

      WHEN OTHERS
      THEN
         g_error_message := 'Error other assignment update' || SQLERRM;
         g_label2 := 'Location';
         g_secondary_column := g_location_name;
         Fnd_File.put_line(Fnd_File.LOG, 'Error api assignment update:'||DBMS_UTILITY.FORMAT_ERROR_STACK );
         RAISE skip_record;
   END;

       /*************************************************************************************************************
    -- PROCEDURE create_load_cll _data
    -- Author: Ravi Pasula
    -- Date:  FEB 05 2013
    -- Parameters:
    -- Description: This procedure LOADS CLL DATA FOR BRZ
    **************************************************************************************************************/
  PROCEDURE Create_CLL_Data_OLD (P_action_type  IN VARCHAR2,
                           P_Person_id    IN VARCHAR2,
                           P_CPF_NUMBER   IN VARCHAR2,
                           P_CTPS_NUMBER  IN VARCHAR2,
                           P_CTPS_ISSUE_DATE IN VARCHAR,
                           P_CTPSSerialNumber IN VARCHAR2,
                           P_PIS          IN NUMBER,
                           P_PISBankNumber IN NUMBER,
                           P_PISIssueDate IN VARCHAR,
                           P_PISProgramType IN VARCHAR2,
                           P_RGExpeditingDate IN VARCHAR,
                           P_RGExpeditorEntity IN VARCHAR2,
                           P_RGLocation   IN VARCHAR2,
                           P_RGState      IN VARCHAR2,
                           P_RGNumber     IN VARCHAR2,
                           P_VoterRegistrationCard IN VARCHAR2,
                           P_VRCSession   IN VARCHAR2,
                           P_VRCState     IN VARCHAR2,
                           P_VRCZone      IN VARCHAR2,
                           P_effective_date IN DATE,
                           P_CPF_FLAG IN VARCHAR2)
IS
BEGIN
   IF P_action_type = 'CREATE'
   THEN
      BEGIN
         INSERT INTO CLL_F038_PERSON_DATA (PERSON_ID,
                                    CPF_NUMBER,
                                    CTPS_NUMBER,
                                   CTPS_ISSUE_DATE,
                                    CTPS_SERIAL_NUMBER,
                                    PIS_PASEP_NUMBER,
                                    PIS_PASEP_BANK_NUMBER,
                                    PIS_PASEP_ISSUE_DATE,
                                    PIS_PASEP_PROGRAM_TYPE,
                                    RG_ISSUE_DATE,
                                    RG_ENTITY,
                                    RG_LOCATION_ISSUE,
                                    RG_STATE,
                                    RG_NUMBER,
                                    ELECTOR_NUMBER,
                                    ELECTOR_NUMBER_SESSION,
                                    ELECTOR_NUMBER_STATE,
                                    ELECTOR_NUMBER_ZONE,
                                    effective_start_date,
                                    effective_end_date,
                                    naturalized_flag,
                                       own_cpf_flag ,
                                         retired_flag,
                                    CREATED_BY,
                                    CREATION_DATE)
              VALUES (P_PERSON_ID,
                      P_CPF_NUMBER,
                      P_CTPS_NUMBER,
                      TO_DATE(P_CTPS_ISSUE_DATE,'YYYY-MM-DD'),
                      P_CTPSSerialNumber,
                      P_PIS,
                      trim(P_PISBankNumber),
                      P_PISIssueDate,
                      P_PISProgramType,
                      P_RGExpeditingDate,
                      P_RGExpeditorEntity,
                      P_RGLocation,
                      P_RGState,
                      P_RGNumber,
                      P_VoterRegistrationCard,
                      P_VRCSession,
                      P_VRCState,
                      P_VRCZone,
                      P_effective_date,
                      to_date('31-DEC-4712'),
                       'N',
                      nvl(P_CPF_FLAG,'Y'), /*V3.6*/
                     'N',
                      FND_GLOBAL.USER_ID,
                      SYSDATE) ;
           EXCEPTION
            WHEN OTHERS
            THEN
               fnd_file.put_line (
                  fnd_file.output,
                  'Failed INSERTING  employee PERSON_id: ' || P_PERSON_ID || SQLERRM);
  END;

ELSIF
        P_action_type =  'REHIRE'  THEN
 BEGIN


    UPDATE  CLL_F038_PERSON_DATA SET
                                        CPF_NUMBER       =        P_CPF_NUMBER ,
                                        CTPS_NUMBER    =    P_CTPS_NUMBER,
                                        CTPS_ISSUE_DATE   =    TO_DATE(P_CTPS_ISSUE_DATE,'YYYY-MM-DD'),
                                        CTPS_SERIAL_NUMBER =  P_CTPSSerialNumber,
                                        PIS_PASEP_NUMBER   =   P_PIS,
                                        PIS_PASEP_BANK_NUMBER  =  P_PISBankNumber,
                                        PIS_PASEP_ISSUE_DATE   =  P_PISIssueDate,
                                        PIS_PASEP_PROGRAM_TYPE =  P_PISProgramType,
                                        RG_ISSUE_DATE  =   P_RGExpeditingDate,
                                        RG_ENTITY   =   P_RGExpeditorEntity,
                                        RG_LOCATION_ISSUE  =   P_RGLocation,
                                        RG_STATE   =   P_RGState,
                                        RG_NUMBER  =  P_RGNumber,
                                        ELECTOR_NUMBER  =  P_VoterRegistrationCard,
                                        ELECTOR_NUMBER_SESSION  = P_VRCSession,
                                        ELECTOR_NUMBER_STATE  = P_VRCState,
                                        ELECTOR_NUMBER_ZONE  =  P_VRCZone
      WHERE
                 PERSON_ID = P_PERSON_ID ;


  EXCEPTION
            WHEN OTHERS
            THEN
               fnd_file.put_line (
                  fnd_file.output,
                  'Failed updating employee PERSON_ID: ' || P_PERSON_ID || SQLERRM);
         END;
END IF;

END;
       /*************************************************************************************************************
    -- PROCEDURE create_load_cll _data
    -- Author: Christiane Chan
    -- Date:  Nov 16 2017
    -- Parameters:
    -- Description: This procedure LOADS CLL DATA FOR BRZ
    **************************************************************************************************************/
  PROCEDURE Create_CLL_Data (P_action_type  IN VARCHAR2,
                           P_Person_id    IN VARCHAR2,
                           P_CPF_NUMBER   IN VARCHAR2,
                           P_CTPS_NUMBER  IN VARCHAR2,
                           P_CTPS_ISSUE_DATE IN VARCHAR,
                           P_CTPSSerialNumber IN VARCHAR2,
                           P_PIS          IN NUMBER,
                           P_PISBankNumber IN NUMBER,
                           P_PISIssueDate IN VARCHAR,
                           P_PISProgramType IN VARCHAR2,
                           P_RGExpeditingDate IN VARCHAR,
                           P_RGExpeditorEntity IN VARCHAR2,
                           P_RGLocation   IN VARCHAR2,
                           P_RGState      IN VARCHAR2,
                           P_RGNumber     IN VARCHAR2,
                           P_VoterRegistrationCard IN VARCHAR2,
                           P_VRCSession   IN VARCHAR2,
                           P_VRCState     IN VARCHAR2,
                           P_VRCZone      IN VARCHAR2,
                           P_EDUCATION_LEVEL IN VARCHAR2, /* 4.0.3 */
                           P_DISABLED_PERSON IN VARCHAR2, /* 4.0.6 */
                           P_FIRSTEMPLOYMENT IN VARCHAR2, /* 4.0.8 */
                           P_RETIRED IN VARCHAR2,     /* 4.0.9 */
                           P_RETIREDCODE IN VARCHAR2, /* 4.0.9 */
                           P_RETIREMENTDATE IN DATE, /* 4.0.9 */
                           P_MILITARYDISCHARGE IN VARCHAR2, /* 4.0.10 */
                           P_effective_date IN DATE,
                           P_CPF_FLAG IN VARCHAR2)
IS
BEGIN
   BEGIN

       IF P_action_type = 'REHIRE'
       THEN
            /* Need to End date prvious record for date tracking purposes, follow by insert to create a new entry if employee is rehired */
            /* Ravi's code was missing this all rehired lost their history */

            UPDATE  CLL_F038_PERSON_DATA
            SET EFFECTIVE_END_DATE = P_effective_date - 1
            WHERE PERSON_ID = P_PERSON_ID
              AND EFFECTIVE_END_DATE = '31-DEC-4712';
       END IF;
   EXCEPTION
            WHEN OTHERS
            THEN
               fnd_file.put_line (
                  fnd_file.output,'Failed updating employee PERSON_ID or No previous record: ' || P_PERSON_ID || SQLERRM);
   END;

   BEGIN
     INSERT INTO CLL_F038_PERSON_DATA (PERSON_ID,
                                CPF_NUMBER,
                                CTPS_NUMBER,
                                CTPS_ISSUE_DATE,
                                CTPS_SERIAL_NUMBER,
                                PIS_PASEP_NUMBER,
                                PIS_PASEP_BANK_NUMBER,
                                PIS_PASEP_ISSUE_DATE,
                                PIS_PASEP_PROGRAM_TYPE,
                                RG_ISSUE_DATE,
                                RG_ENTITY,
                                RG_LOCATION_ISSUE,
                                RG_STATE,
                                RG_NUMBER,
                                ELECTOR_NUMBER,
                                ELECTOR_NUMBER_SESSION,
                                ELECTOR_NUMBER_STATE,
                                ELECTOR_NUMBER_ZONE,
                                EDUCATION_LEVEL, /* 4.0.3 */
                                DISABLED_PERSON, /* 4.0.6 */
                                ATTRIBUTE1,  /* 4.0.8 */
                                RETIRED_FLAG, /* 4.0.9 */
                                RETIREMENT_DATE, /* 4.0.9 */
                                RETIREMENT_REASON, /* 4.0.9 */
                                --INSS_NUMBER, /* 4.0.9 */
                                RESERVIST_NUMBER, /* 4.0.10 */
                                effective_start_date,
                                effective_end_date,
                                naturalized_flag,
                                own_cpf_flag ,
                                --retired_flag,/* 4.0.9 */
                                CREATED_BY,
                                CREATION_DATE)
          VALUES (P_PERSON_ID,
                  P_CPF_NUMBER,
                  P_CTPS_NUMBER,
                  TO_DATE(P_CTPS_ISSUE_DATE,'YYYY-MM-DD'),
                  P_CTPSSerialNumber,
                  P_PIS,
                  trim(P_PISBankNumber),
                  P_PISIssueDate,
                  P_PISProgramType,
                  P_RGExpeditingDate,
                  P_RGExpeditorEntity,
                  P_RGLocation,
                  P_RGState,
                  P_RGNumber,
                  P_VoterRegistrationCard,
                  P_VRCSession,
                  P_VRCState,
                  P_VRCZone,
                  P_EDUCATION_LEVEL, /* 4.0.3 */
                  P_DISABLED_PERSON, /* 4.0.6 */
                  P_FIRSTEMPLOYMENT, /* 4.0.8 */
                  P_RETIRED, /* 4.0.9 */
                  P_RETIREMENTDATE, /* 4.0.9 */
                  P_RETIREDCODE, /* 4.0.9 */
                  P_MILITARYDISCHARGE, /* 4.0.10 */
                  P_effective_date,
                  to_date('31-DEC-4712'),
                  'N',
                  nvl(P_CPF_FLAG,'Y'), /*V3.6*/
                  --'N', /* 4.0.9 */
                  FND_GLOBAL.USER_ID,
                  SYSDATE) ;
   EXCEPTION
        WHEN OTHERS
        THEN
           fnd_file.put_line (
              fnd_file.output,
              'Failed INSERTING  employee PERSON_id: ' || P_PERSON_ID || SQLERRM);
   END;

END;
    /*************************************************************************************************************
    -- PROCEDURE create_costing
    -- Author: Ibrahim Konak
    -- Date:  Feb 26 2007
    -- Parameters:
    -- Description: This procedure creates costing record of the employee.
    **************************************************************************************************************/
   PROCEDURE create_costing (
          p_validate            IN   BOOLEAN    DEFAULT FALSE,
          p_effective_date      IN   DATE,
          p_assignment_id       IN   NUMBER,
          p_business_group_id   IN   NUMBER,
          p_proportion          IN   NUMBER     DEFAULT NULL,
          p_segment1            IN   VARCHAR2   DEFAULT NULL,
          p_segment2            IN   VARCHAR2   DEFAULT NULL,
          p_segment3            IN   VARCHAR2   DEFAULT NULL
   )
   IS
      l_organization_id    per_all_assignments_f.ORGANIZATION_ID%TYPE;
      l_location_id        per_all_assignments_f.location_id%TYPE;
      l_success_flag    Tt_Hrms_Api_Utility_Pkg.g_success_flag%TYPE;
      l_error_message   VARCHAR2 (250);

   BEGIN
      g_module_name := 'create_costing';


      Tt_Hrms_Api_Utility_Pkg.create_costing
                            (ip_validate               => p_validate,
                             ip_effective_date         => p_effective_date,
                             ip_assignment_id          => p_assignment_id,
                             ip_business_group_id      => p_business_group_id,
                             ip_proportion             => p_proportion,
                             ip_segment1               => p_segment1,
                             ip_segment2               => p_segment2,
                             ip_segment3               => p_segment3,
                             op_success_flag           => l_success_flag,
                             op_error_message          => l_error_message
                            );

      IF l_success_flag = 'N'
      THEN
         RAISE api_error;

      END IF;


   EXCEPTION
      WHEN api_error
      THEN
         g_error_message := 'Error Costing Create API' || l_error_message;
         RAISE skip_record;
      WHEN OTHERS

      THEN
         g_error_message := 'Error Other Costing Create API' || l_error_message;
       --  g_label2 := 'Client';             /* Version 1.10 */
       --  g_secondary_column := p_segment2; /* Version 1.10 */
         RAISE skip_record;
   --Warning
   END;

    /*************************************************************************************************************
    -- PROCEDURE create_bill_at_will
    -- Author: Ibrahim Konak
    -- Date:  Feb 26 2007
    -- Parameters:
    -- Description: This procedure creates bill at will record of the employee.
    **************************************************************************************************************/
   PROCEDURE create_bill_at_will (
             p_person_id            IN NUMBER,
             p_employee_number      IN VARCHAR2,
             p_client_code          IN VARCHAR2     DEFAULT NULL,
             p_client_desc          IN VARCHAR2     DEFAULT NULL,
             p_program              IN VARCHAR2     DEFAULT NULL,
             p_program_desc         IN VARCHAR2     DEFAULT NULL,
             p_project              IN VARCHAR2     DEFAULT NULL,
             p_project_desc         IN VARCHAR2     DEFAULT NULL,
             p_project_start        IN DATE         DEFAULT NULL,
             p_project_end          IN DATE         DEFAULT NULL,
             p_full_name            IN VARCHAR2,
             p_business_group_id    IN NUMBER,
             p_location_id          IN NUMBER,
             p_emp_type             IN VARCHAR2,
             p_person_type          IN VARCHAR2     DEFAULT NULL
             )
   IS
       CURSOR c_usr_per_type IS
       SELECT DISTINCT user_person_type
       FROM  per_person_types
       WHERE person_type_id = p_person_type;

       v_emp_type  per_person_types.user_person_type%TYPE;

   BEGIN
       IF p_emp_type = 'CWK'
       THEN

            IF p_person_type IS NOT NULL
            THEN

                OPEN c_usr_per_type;

                FETCH c_usr_per_type
                INTO v_emp_type;

                CLOSE c_usr_per_type;
            END IF;

            IF v_emp_type IS NULL
            THEN

               v_emp_type := 'Contingent Worker - Agency Temp';

            END IF;

       ELSE
           v_emp_type := 'Employee';

       END IF;

       INSERT INTO ttec_emp_proj_asg
                     ( person_id          ,
                       employee_number    ,
                       clt_cd             ,
                       client_desc        ,
                       prog_cd            ,
                       program_desc       ,
                       prj_cd             ,
                       project_desc       ,
                       prj_strt_dt        ,
                       prj_end_dt         ,
                       proportion         ,
                       last_update_date   ,
                       last_update_by     ,
                       last_update_login  ,
                       created_by         ,
                       creation_date      ,
                       full_name          ,
                       emp_type           ,
                       business_group_id  ,
                       location_id
                      )
              VALUES (p_person_id,
                      p_employee_number,
                      p_client_code,
                      p_client_desc,
                      p_program,
                      p_program_desc,
                      p_project,
                      p_project_desc,
                      p_project_start,
                      p_project_end,
                      100, --proportion
                      TRUNC (SYSDATE),  --last_update_date
                      -2,   --last_updated_by
                      -2,   --last_update_login
                      -2,   --created_by
                      TRUNC (SYSDATE),  --creation_date
                      p_full_name,
                      v_emp_type,  --'Employee',  --emp_type
                      p_business_group_id,
                      p_location_id
                     ); -- Commented as part of 7.5

   EXCEPTION
        WHEN OTHERS
        THEN
            g_error_message     := 'Error Bill at Will create' || SQLERRM;
            g_label2            := 'Location';
            g_secondary_column  := g_location_name;
            RAISE skip_record;
   END;

    /*************************************************************************************************************
    -- PROCEDURE create_salary
    -- Author: Ibrahim Konak
    -- Date:  Feb 26 2007
    -- Parameters:
    -- Description: This procedure creates salary proposal  record of the employee.
    **************************************************************************************************************/
   PROCEDURE create_salary (
      p_validate              IN   BOOLEAN DEFAULT FALSE,
      p_effective_date        IN   DATE,
      p_assignment_id         IN   NUMBER,
      p_business_group_id     IN   NUMBER,
      p_proposed_salary_n     IN   NUMBER DEFAULT NULL,
      p_multiple_components   IN   VARCHAR2 DEFAULT 'N',
      p_approved              IN   VARCHAR2 DEFAULT 'Y'
   )
   IS
      l_success_flag    g_success_flag%TYPE;
      l_error_message   g_error_message%TYPE;
      l_reason          per_pay_proposals.proposal_reason%TYPE;
   BEGIN

      g_module_name := 'create_salary';

      IF g_action_type = 'REHIRE'
      THEN
         l_reason := 'REH';
        ELSE
         l_reason := 'IDL';
      END IF;
      /*2.6 BRZ REASON */

      Tt_Hrms_Api_Utility_Pkg.create_salary
                             (ip_validate                 => p_validate,
                              ip_effective_date           => p_effective_date,
                              ip_assignment_id            => p_assignment_id,
                              ip_business_group_id        => p_business_group_id,
                              ip_proposal_reason          => l_reason,
                              ip_proposed_salary_n        => p_proposed_salary_n,
                              ip_multiple_components      => p_multiple_components,
                              ip_approved                 => p_approved,
                              op_success_flag             => l_success_flag,
                              op_error_message            => l_error_message
                             );
     fnd_file.put_line(fnd_file.output, 'Proposal_reason:'|| l_reason);

      IF l_success_flag = 'N'
      THEN
         RAISE api_error;
          fnd_file.put_line(fnd_file.output, 'Proposal_reason2:'|| l_reason);
      END IF;

   EXCEPTION
      WHEN api_error
      THEN
         g_error_message    := 'Error salary create API' || l_error_message;
         g_label2           := 'Location';
         g_secondary_column := g_location_name;
         RAISE skip_record;

      WHEN OTHERS
      THEN
         g_error_message    := 'Error other salary create API' || SQLERRM;
         g_label2           := 'Location';
         g_secondary_column := g_location_name;
         RAISE skip_record;
   END;

    /*************************************************************************************************************
    -- PROCEDURE update_sui_state
    -- Author: Ibrahim Konak
    -- Date:  Feb 26 2007
    -- Parameters:
    -- Description: This procedure updates SUI State if different from prmary state for work at home US employee.
    **************************************************************************************************************/
    PROCEDURE update_sui_state  (
          p_business_group_id   IN  NUMBER,
          p_person_id           IN  NUMBER,
          p_assignment_id       IN  NUMBER,
          p_effective_date      IN  DATE,
          p_work_at_home        IN  VARCHAR2
          )
    IS
        v_effective_start_date  DATE;
        v_effective_end_date    DATE;
        v_state                 VARCHAR2(50);
        v_sui_state             VARCHAR2(50);
        v_state_code            VARCHAR2(50);
        v_object_version_number pay_us_emp_fed_tax_rules_f.object_version_number%TYPE;
        v_emp_fed_tax_rule_id   pay_us_emp_fed_tax_rules_f.emp_fed_tax_rule_id%TYPE;


        CURSOR c_primary_state IS
        SELECT a.region_2 FROM per_addresses_v a
        WHERE a.person_id = p_person_id
        AND a.primary_flag = 'Y'
        AND a.address_type = 'HOME'
        AND a.date_from = (SELECT MAX(b.date_from) FROM per_addresses_v b
                         WHERE b.person_id = a.person_id
                         AND b.primary_flag = 'Y'
                         AND b.address_type = 'HOME');

        CURSOR c_sui_state IS
            SELECT b.state_abbrev FROM pay_us_emp_fed_tax_rules_f a,pay_us_states b
            WHERE  a.sui_state_code = b. state_code
            AND a.assignment_id = p_assignment_id
            AND a.effective_start_date =
            (SELECT MAX(c.effective_start_date) FROM pay_us_emp_fed_tax_rules_f c
             WHERE c.assignment_id = a.assignment_id);

        CURSOR c_get_state_code(p_state VARCHAR2) IS
        SELECT state_code
        FROM pay_us_states
        WHERE state_abbrev = p_state;

        CURSOR c_obj_ver IS
        SELECT a.object_version_number,a.emp_fed_tax_rule_id
        FROM pay_us_emp_fed_tax_rules_f a
        WHERE a.assignment_id = p_assignment_id
        AND a.effective_start_date =
            (SELECT MAX(b.effective_start_date) FROM pay_us_emp_fed_tax_rules_f b
             WHERE b.assignment_id = a.assignment_id);

    BEGIN

        IF NVL(UPPER(p_work_at_home),'N') = 'Y'
        THEN
            IF p_business_group_id = 325
            THEN

                OPEN c_primary_state;

                FETCH c_primary_state
                INTO v_state;

                CLOSE c_primary_state;

                OPEN c_sui_state;

                FETCH c_sui_state
                INTO v_sui_state;

                CLOSE c_sui_state;

                IF NVL(v_sui_state,'xxx') <> NVL(v_state,'xxx')
                THEN

                    OPEN c_get_state_code(v_state);

                    FETCH c_get_state_code
                    INTO v_state_code;

                    CLOSE c_get_state_code;

                    OPEN c_obj_ver;

                    FETCH c_obj_ver
                    INTO v_object_version_number,v_emp_fed_tax_rule_id;

                    CLOSE c_obj_ver;

                    pay_federal_tax_rule_api.update_fed_tax_rule
                            (p_effective_date           => p_effective_date,
                             p_datetrack_update_mode    => 'CORRECTION',
                             p_emp_fed_tax_rule_id      => v_emp_fed_tax_rule_id,
                             p_object_version_number    => v_object_version_number,
                             p_sui_state_code           => v_state_code,
                             p_effective_start_date     => v_effective_start_date,
                             p_effective_end_date       => v_effective_end_date
                             );
                END IF;

            END IF;

         END IF;

    EXCEPTION
         WHEN OTHERS
         THEN
             g_error_message    := 'Error other US SUI Update API' || SQLERRM;
             --As per Wasim using glabel2 and employee number
             g_label2           := 'Employee Number';
             g_secondary_column := g_employee_number;
             RAISE skip_record;

    END update_sui_state;

    /*************************************************************************************************************
    -- PROCEDURE create_ca_sui_state
    -- Author: Ibrahim Konak
    -- Date:  Feb 26 2007
    -- Parameters:
    -- Description: This procedure creates SUI State if different from prmary province for work at home CAN employee.
    **************************************************************************************************************/
    PROCEDURE create_ca_sui_state (
          p_business_group_id   IN  NUMBER,
          p_person_id           IN  NUMBER,
          p_assignment_id       IN  NUMBER,
          p_effective_date      IN  DATE,
          p_work_at_home        IN  VARCHAR2 )
        IS

        v_error                 VARCHAR2(200);
        v_emp_fed_tax_inf_id    NUMBER;
        v_effective_start_date  DATE;
        v_effective_end_date    DATE;
        v_object_version_number NUMBER;
        v_fed_province          VARCHAR2(30);
        v_prov_province         VARCHAR2(30);
        v_province              VARCHAR2(30);

        CURSOR c_primary_province IS
        SELECT a.region_1 FROM per_addresses_v a
        WHERE a.person_id = p_person_id
        AND a.primary_flag = 'Y'
        AND a.address_type = 'HOME'
        AND a.date_from = (SELECT MAX(b.date_from) FROM per_addresses_v b
                         WHERE b.person_id = a.person_id
                         AND b.primary_flag = 'Y'
                         AND b.address_type = 'HOME');

        CURSOR c_fed_province IS
        SELECT employment_province
        FROM pay_ca_emp_fed_tax_info_f a
        WHERE a.assignment_id = p_assignment_id
        AND a.effective_start_date =
            (SELECT MAX(c.effective_start_date) FROM pay_ca_emp_fed_tax_info_f c
             WHERE c.assignment_id = a.assignment_id);

        CURSOR c_prov_province IS
        SELECT province_code
        FROM pay_ca_emp_prov_tax_info_f  a
        WHERE a.assignment_id = p_assignment_id
        AND a.effective_start_date =
            (SELECT MAX(c.effective_start_date) FROM pay_ca_emp_prov_tax_info_f c
             WHERE c.assignment_id = a.assignment_id);

    BEGIN

        IF NVL(UPPER(p_work_at_home),'N') = 'Y'
        THEN

            IF p_business_group_id = 326
            THEN

                OPEN c_primary_province;

                FETCH c_primary_province
                INTO v_province;

                CLOSE c_primary_province;

                OPEN c_fed_province;

                FETCH c_fed_province
                INTO v_fed_province;

                CLOSE c_fed_province;

                IF v_fed_province IS NULL
                THEN
                    BEGIN
                       pay_ca_emp_fedtax_inf_api.create_ca_emp_fedtax_inf
                           (p_emp_fed_tax_inf_id    => v_emp_fed_tax_inf_id,
                            p_effective_start_date  => v_effective_start_date,
                            p_effective_end_date    => v_effective_end_date,
                            p_legislation_code      => 'CA',
                            p_assignment_id         => p_assignment_id,
                            p_business_group_id     => 326,
                            p_employment_province   => v_province,
                            p_basic_exemption_flag  => 'Y',
                            p_object_version_number => v_object_version_number,
                            p_effective_date        => p_effective_date,
                            p_cpp_election_date => NULL, -- p_effective_date, Modified as part of 7.8
                            p_cpp_revocation_date => NULL -- '31-DEC-4712' /* 2.7 */ Modified as part of 7.8
                            );

                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            g_error_message     := 'Error in others Exception CAN Federal SUI Create API' || SQLERRM;
                            --As per Wasim using glabel2 and employee number
                            g_label2            := 'Employee Number';
                            g_secondary_column  := g_employee_number;
                            RAISE skip_record;
                    END;

                END IF;

                OPEN c_prov_province;

                FETCH c_prov_province
                INTO v_prov_province;

                IF v_prov_province IS NULL
                THEN
                    BEGIN

                        pay_ca_emp_prvtax_inf_api.create_ca_emp_prvtax_inf(
                            p_emp_province_tax_inf_id   => v_emp_fed_tax_inf_id,
                            p_effective_start_date      => v_effective_start_date,
                            p_effective_end_date        => v_effective_end_date,
                            p_legislation_code          => 'CA',
                            p_assignment_id             => p_assignment_id,
                            p_business_group_id         => 326,
                            p_province_code             => v_province,
                            p_basic_exemption_flag      => 'Y',
                            p_object_version_number     => v_object_version_number,
                            p_effective_date            => p_effective_date
                            );

                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            g_error_message     := 'Error in others Exception CAN Province SUI Create API' || SQLERRM;
                            --As per Wasim using glabel2 and employee number
                            g_label2            := 'Employee Number';
                            g_secondary_column  := g_employee_number;
                            RAISE skip_record;
                    END;

                END IF;

            END IF;

         END IF;


    EXCEPTION
        WHEN OTHERS
        THEN
            g_error_message    := 'Error in others Exception CAN SUI Create API' || SQLERRM;
            --As per Wasim using glabel2 and employee number
            g_label2           := 'Employee Number';
            g_secondary_column := g_employee_number;
            RAISE skip_record;

    END create_ca_sui_state;

    /*************************************************************************************************************
    -- PROCEDURE report_new_hire
    -- Author: Ibrahim Konak
    -- Date:  Feb 26 2007
    -- Parameters:
    -- Description: This procedure reports employee numbers created for the candidates.
    **************************************************************************************************************/
   PROCEDURE report_new_hire
   IS
      CURSOR c_emp
      IS
         (SELECT   *
           --FROM cust.TTEC_TALEO_STAGE				-- Commented code by IXPRAVEEN-ARGANO,14-july-2023
           FROM apps.TTEC_TALEO_STAGE               --  code Added by IXPRAVEEN-ARGANO,   14-july-2023
          WHERE
            oracle_load_sucess = 1
            AND concurrent_update_id = Fnd_Global.conc_request_id);
   BEGIN
      -- set global module name for error handling
      g_module_name := 'report new hire';
      -- output header
      print_line ('');
      print_line ('');
      print_line
         ('----------------------------------------------------------------------------------'

         );
      print_line ('TALEO RECONCILIATION REPORT  ');
      print_line
         ('----------------------------------------------------------------------------------'
         );
      print_line ('');
      print_line
               ('   CANDIDATE      EMPLOYEE     CWK             LAST NAME          FIRST NAME');
      print_line
            ('   ------------   --------     -----------        ----------         ------------ ');

      FOR r_emp IN c_emp
      LOOP
         NULL;

         print_line (   '   '
                     || RPAD (NVL (TO_CHAR(r_emp.cand_id), ' '), 15)
                     || RPAD (NVL (r_emp.employee_number, ' '), 13)
                     || RPAD (NVL (r_emp.npw_number,' '),13)
                     || RPAD (NVL (r_emp.lastname, ' '), 19)
                     || RPAD (NVL (r_emp.firstname, ' '), 19)
                    );

      END LOOP;

      print_line ('');
      print_line
         ('-----------------------------------------------------------------------------'
         );
      print_line

         ('---------------------------------- REPORT END  ------------------------------'
         );
      print_line
         ('-----------------------------------------------------------------------------'
         );
      print_line ('');
   EXCEPTION
      WHEN OTHERS
      THEN
         print_line
            ('ERROR:  COULD NOT COMPLETE THE RECONCILIATION REPORT.'
            );
         g_error_message    := 'Summary Report Error' || SQLERRM;

         g_label2           := '';
         g_secondary_column := '';
         log_error;
   END;


    /*************************************************************************************************************
    -- PROCEDURE import_new_hire
    -- Author: Ibrahim Konak
    -- Date:  Feb 26 2007
    -- Parameters:
    -- Description: This is the MAIN procedure inside the pkg. This procedure inserts employee records into Oracle.
    -- Modification Log

    -- Version    Developer              Date         Description
    -- ---        ----------------    -----------     --------------------------------
    -- 1.0        Ibrahim Konak       Feb 26 2007     Created.
    -- 1.1        Elango Pandu        Nov 19 2007     Added CWK Part
    -- 1.2.1      MLagostena          Aug 08 2008     Added default values for PHL to update_assignment proc
    -- 1.2.2      NMondada            Aug 08 2008     Modified proc update_address to end date Non-primary
                                                      address for employees during the rehire process
    -- 1.3.1      NMondada            Nov 05 2008     Terminate all primary and secondary addresses without
                                                      checking for changes, and create a new primary address.
    -- 1.3.2      MLagostena          Nov 05 2008     Modified procedure get_rehire_person to handle UK rehires
                                                      (which allow null NINS) as PHL rehires.
    -- 1.4        MLagostena          Jan 23 2008     Added South Africa to the Integration.
    -- 1.5        MLagostena          Jan 26 2009     Added Argentina to the Integration.
    -- 1.6.1      NMondada            Mar 30 2009     Added Mexico to the Integration.
    -- 1.6.2      MLagostena          May 26 2009    Added Race/Ethnicity Field Validation Change (US)
    -- 1.7        CChan               Jun 04 2009     Added cost Rica to the Integration.
    -- 1.9        CChan               Jan 18 2010     Added Religion Capture Method to UK
       2.0        Venkata Kovvuri     Sep 14 2021     Modified the code to upload candidates from Taleo with out CPP validation
       2.1        Venkata Kovvuri     Sep 17,2021     Reverted the 2.0 changes and modified CPP synonym to CPP external tables
    **************************************************************************************************************/
   PROCEDURE import_new_hire (errbuf OUT VARCHAR2, retcode OUT NUMBER)
   IS

      l_business_group_id            per_all_people_f.business_group_id%TYPE;
      l_security_group_id            NUMBER;
      l_per_object_version_number    per_all_people_f.object_version_number%TYPE;
      l_gender_code                  hr_lookups.lookup_code%TYPE;
      l_ethnicity_code               hr_lookups.lookup_code%TYPE;
      l_rehire_reason_code           hr_lookups.lookup_code%TYPE;
      l_rehire_eligible              per_periods_of_service.attribute9%TYPE;
      l_leav_reason                  per_periods_of_service.leaving_reason%TYPE;
      l_final_process_date           per_periods_of_service.final_process_date%TYPE;
      l_period_of_service_id         per_periods_of_service.period_of_service_id%TYPE;
      l_ppos_object_version_number   per_periods_of_service.object_version_number%TYPE;
      l_employee_number              per_all_people_f.employee_number%TYPE;
      l_full_name                    per_all_people_f.full_name%TYPE;
      l_person_id                    per_all_people_f.person_id%TYPE;
      l_person_type_id               per_person_types.person_type_id%TYPE;
      l_assignment_number            per_all_assignments_f.assignment_number%TYPE;
      l_asg_object_version_number    per_all_assignments_f.object_version_number%TYPE;
      l_assignment_id                per_all_assignments_f.assignment_id%TYPE;
      l_location_id                  per_all_assignments_f.location_id%TYPE;
      l_gre_id                       hr_organization_units.organization_id%TYPE;
      l_gre_name                     hr_organization_units.NAME%TYPE;
      l_work_schedule_id             hr_organization_information.attribute1%TYPE;
      l_payroll_id                   per_all_assignments_f.payroll_id%TYPE;
      l_payroll_name                 pay_payrolls_f.payroll_name%TYPE;
      l_job_id                       per_all_assignments_f.job_id%TYPE;
      l_pay_basis_id                 per_pay_bases.pay_basis_id%TYPE;
      l_employment_category          per_all_assignments_f.employment_category%TYPE;
      --l_client_desc                ttec_client.desc_shrt%TYPE; --Commented by 2.0
      l_client_desc                  TTEC_CLIENT_EXT.desc_shrt%TYPE; --Added as part of 2.1
      --l_client_desc                varchar2(1000); -- Added by 2.0
      l_timecard_approval            hr_soft_coding_keyflex.segment3%TYPE;
      l_timecard_required            hr_soft_coding_keyflex.segment3%TYPE;
      l_supervisor_id                per_all_assignments_f.supervisor_id%TYPE;
      l_organization_id              per_all_assignments_f.organization_id%TYPE;
      l_county                       per_addresses.region_1%TYPE;
      l_start_date                   DATE;
      l_dob_date                     DATE;
      l_national_identifier          per_all_people_f.national_identifier%TYPE;

      /* Version 1.4 - ZA Integration */
      l_registered_disabled_flag     per_all_people_f.REGISTERED_DISABLED_FLAG%TYPE;
     /*l_study_level                  cust.ttec_taleo_stage.studylevel%TYPE;

      /* Version 1.5 - ARG Integration */
    /*  l_addressdistrict              cust.ttec_taleo_stage.addressdistrict%TYPE;
      l_addressneighborhood          cust.ttec_taleo_stage.addressneighborhood%TYPE;
      l_addressmunicipality          cust.ttec_taleo_stage.addressneighborhood%TYPE;
      l_sstype                       cust.ttec_taleo_stage.sstype%TYPE;
      l_socialsecurityid             cust.ttec_taleo_stage.socialsecurityid%TYPE;
      l_stateprovincedes             cust.ttec_taleo_stage.stateprovincedes%TYPE;
      l_birthcountry                 cust.ttec_taleo_stage.birthcountry%TYPE;

      /* Version 1.6.1 - MEX Integration */
      /*l_birthregion                  cust.ttec_taleo_stage.birthregion%TYPE;
      l_birthtown                    cust.ttec_taleo_stage.birthtown%TYPE;
      l_birthstate                   cust.ttec_taleo_stage.birthstate%TYPE;
      l_unionaffiliation             cust.ttec_taleo_stage.unionaffiliation%TYPE;
      l_industry                     cust.ttec_taleo_stage.industry%TYPE;
      l_maternalname                 cust.ttec_taleo_stage.maternalname%TYPE;
      l_ss_salary_type               cust.ttec_taleo_stage.ss_salary_type%TYPE;
      l_contract_type                cust.ttec_taleo_stage.contract_type%TYPE;
      l_shift                        cust.ttec_taleo_stage.shift%TYPE;
      l_workforce                    cust.ttec_taleo_stage.workforce%TYPE;
      l_stateprovincecode            cust.ttec_taleo_stage.stateprovincecode%TYPE;
      /* Version 5.0 - Motif India Integration */
      /*L_RESIDENTSTATUS                 CUST.TTEC_TALEO_STAGE.RESIDENTSTATUS%TYPE;
      L_LIVEINADDRSINCE                 CUST.TTEC_TALEO_STAGE.LIVEINADDRSINCE%TYPE;
      L_PANCARDNUMBER                 CUST.TTEC_TALEO_STAGE.PANCARDNUMBER%TYPE;
      L_PANCARDNAME                     CUST.TTEC_TALEO_STAGE.PANCARDNAME%TYPE;
      L_ADHARCARDNUMBER                 CUST.TTEC_TALEO_STAGE.ADHARCARDNUMBER%TYPE;
      L_ADHARCARDNAME                 CUST.TTEC_TALEO_STAGE.ADHARCARDNAME%TYPE;
      L_VOTERID                         CUST.TTEC_TALEO_STAGE.VOTERID%TYPE;
      L_EPFNUMBER                     CUST.TTEC_TALEO_STAGE.EPFNUMBER%TYPE;
      L_UANNUMBER                     CUST.TTEC_TALEO_STAGE.UANNUMBER%TYPE;
      L_CORRESPADDRESS                 CUST.TTEC_TALEO_STAGE.CORRESPADDRESS%TYPE;
      L_CORRESPADDRESS2                 CUST.TTEC_TALEO_STAGE.CORRESPADDRESS2%TYPE;
      L_CORRESPCITY                     CUST.TTEC_TALEO_STAGE.CORRESPCITY%TYPE;
      L_CORRESPSTATE                 CUST.TTEC_TALEO_STAGE.CORRESPSTATE%TYPE;
      L_CORRESPZIPCODE                 CUST.TTEC_TALEO_STAGE.CORRESPZIPCODE%TYPE;
      L_CORRESPCOUNTRYCODE           CUST.TTEC_TALEO_STAGE.CORRESPCOUNTRYCODE%TYPE;

      /* Version 1.6.2 - US Ethnic enhancement */
      --l_ethnic_disclosed             cust.ttec_taleo_stage.ETHNIC_DISCLOSED%TYPE;

      /* Version 1.7 - Costa Rica Integration */
      --l_LanguageDifferential         cust.ttec_taleo_stage.Language_Differential%TYPE;

      /* Version 1.8 -  ZA Visa Expiration Date enhancement  */
      --l_VisaExpirationDate           cust.ttec_taleo_stage.VisaExpirationDate%TYPE;
      /* Version 1.9 --  Add Religion Capture Method to UK */
      --l_fec_feedervalue              cust.ttec_taleo_stage.fec_feedervalue%TYPE;
      /* Version 7.0  - International Integration */
      --l_ANNUALTENUREPAY              cust.ttec_taleo_stage.ANNUALTENUREPAY%TYPE; /* 7.0 */
      --
     /* l_success_flag                 g_success_flag%TYPE;
      l_error_message                g_error_message%TYPE;

      -- declare local control total variables
      l_records_read                 NUMBER := 0;
      l_records_processed            NUMBER := 0;
      l_records_errored              NUMBER := 0;
      l_records_rehire               NUMBER := 0;
      l_records_active               NUMBER := 0;
      l_records_employee_create      NUMBER := 0;

      l_marital_status               per_all_people_f.marital_status%TYPE;
      l_npw_number                   per_all_people_f.npw_number%TYPE;


      l_sys_per_type                 cust.ttec_taleo_stage.sys_per_type%TYPE;
      l_person_type                  cust.ttec_taleo_stage.person_type%TYPE;
      l_cwk_rate_type                cust.ttec_taleo_stage.rate_type%TYPE;
      l_agency_name                  cust.ttec_taleo_stage.agency_name%TYPE;
      l_rfc_id                       cust.ttec_taleo_stage.rfc_id%TYPE; /* 3.5.3 */
      /*l_ARBITRATION_AGREEMENT        cust.ttec_taleo_stage.ARBITRATION_AGREEMENT%TYPE; /* 6.3 */
	  --l_cpf_number                   cust.ttec_taleo_stage.cpf_number%TYPE; /* 6.8 */

      --ln_rg_number                   cust.ttec_taleo_stage.rgnumber%TYPE;   --Added for v6.6 --Vaitheghi */
	  l_study_level                  apps.ttec_taleo_stage.studylevel%TYPE;

      /* Version 1.5 - ARG Integration */
      l_addressdistrict              apps.ttec_taleo_stage.addressdistrict%TYPE;
      l_addressneighborhood          apps.ttec_taleo_stage.addressneighborhood%TYPE;
      l_addressmunicipality          apps.ttec_taleo_stage.addressneighborhood%TYPE;
      l_sstype                       apps.ttec_taleo_stage.sstype%TYPE;
      l_socialsecurityid             apps.ttec_taleo_stage.socialsecurityid%TYPE;
      l_stateprovincedes             apps.ttec_taleo_stage.stateprovincedes%TYPE;
      l_birthcountry                 apps.ttec_taleo_stage.birthcountry%TYPE;

      /* Version 1.6.1 - MEX Integration */
      l_birthregion                  apps.ttec_taleo_stage.birthregion%TYPE;
      l_birthtown                    apps.ttec_taleo_stage.birthtown%TYPE;
      l_birthstate                   apps.ttec_taleo_stage.birthstate%TYPE;
      l_unionaffiliation             apps.ttec_taleo_stage.unionaffiliation%TYPE;
      l_industry                     apps.ttec_taleo_stage.industry%TYPE;
      l_maternalname                 apps.ttec_taleo_stage.maternalname%TYPE;
      l_ss_salary_type               apps.ttec_taleo_stage.ss_salary_type%TYPE;
      l_contract_type                apps.ttec_taleo_stage.contract_type%TYPE;
      l_shift                        apps.ttec_taleo_stage.shift%TYPE;
      l_workforce                    apps.ttec_taleo_stage.workforce%TYPE;
      l_stateprovincecode            apps.ttec_taleo_stage.stateprovincecode%TYPE;
      /* Version 5.0 - Motif India Integration */
      L_RESIDENTSTATUS                 apps.TTEC_TALEO_STAGE.RESIDENTSTATUS%TYPE;
      L_LIVEINADDRSINCE                 apps.TTEC_TALEO_STAGE.LIVEINADDRSINCE%TYPE;
      L_PANCARDNUMBER                 apps.TTEC_TALEO_STAGE.PANCARDNUMBER%TYPE;
      L_PANCARDNAME                     apps.TTEC_TALEO_STAGE.PANCARDNAME%TYPE;
      L_ADHARCARDNUMBER                 apps.TTEC_TALEO_STAGE.ADHARCARDNUMBER%TYPE;
      L_ADHARCARDNAME                 apps.TTEC_TALEO_STAGE.ADHARCARDNAME%TYPE;
      L_VOTERID                         apps.TTEC_TALEO_STAGE.VOTERID%TYPE;
      L_EPFNUMBER                     apps.TTEC_TALEO_STAGE.EPFNUMBER%TYPE;
      L_UANNUMBER                     apps.TTEC_TALEO_STAGE.UANNUMBER%TYPE;
      L_CORRESPADDRESS                 apps.TTEC_TALEO_STAGE.CORRESPADDRESS%TYPE;
      L_CORRESPADDRESS2                 apps.TTEC_TALEO_STAGE.CORRESPADDRESS2%TYPE;
      L_CORRESPCITY                     apps.TTEC_TALEO_STAGE.CORRESPCITY%TYPE;
      L_CORRESPSTATE                 apps.TTEC_TALEO_STAGE.CORRESPSTATE%TYPE;
      L_CORRESPZIPCODE                 apps.TTEC_TALEO_STAGE.CORRESPZIPCODE%TYPE;
      L_CORRESPCOUNTRYCODE           apps.TTEC_TALEO_STAGE.CORRESPCOUNTRYCODE%TYPE;

      /* Version 1.6.2 - US Ethnic enhancement */
      l_ethnic_disclosed             apps.ttec_taleo_stage.ETHNIC_DISCLOSED%TYPE;

      /* Version 1.7 - Costa Rica Integration */
      l_LanguageDifferential         apps.ttec_taleo_stage.Language_Differential%TYPE;

      /* Version 1.8 -  ZA Visa Expiration Date enhancement  */
      l_VisaExpirationDate           apps.ttec_taleo_stage.VisaExpirationDate%TYPE;
      /* Version 1.9 --  Add Religion Capture Method to UK */
      l_fec_feedervalue              apps.ttec_taleo_stage.fec_feedervalue%TYPE;
      /* Version 7.0  - International Integration */
      l_ANNUALTENUREPAY              apps.ttec_taleo_stage.ANNUALTENUREPAY%TYPE; /* 7.0 */
      --
      l_success_flag                 g_success_flag%TYPE;
      l_error_message                g_error_message%TYPE;

      -- declare local control total variables
      l_records_read                 NUMBER := 0;
      l_records_processed            NUMBER := 0;
      l_records_errored              NUMBER := 0;
      l_records_rehire               NUMBER := 0;
      l_records_active               NUMBER := 0;
      l_records_employee_create      NUMBER := 0;

      l_marital_status               per_all_people_f.marital_status%TYPE;
      l_npw_number                   per_all_people_f.npw_number%TYPE;


      l_sys_per_type                 apps.ttec_taleo_stage.sys_per_type%TYPE;
      l_person_type                  apps.ttec_taleo_stage.person_type%TYPE;
      l_cwk_rate_type                apps.ttec_taleo_stage.rate_type%TYPE;
      l_agency_name                  apps.ttec_taleo_stage.agency_name%TYPE;
      l_rfc_id                       apps.ttec_taleo_stage.rfc_id%TYPE; /* 3.5.3 */
      l_ARBITRATION_AGREEMENT        apps.ttec_taleo_stage.ARBITRATION_AGREEMENT%TYPE; /* 6.3 */
	  l_cpf_number                   apps.ttec_taleo_stage.cpf_number%TYPE; /* 6.8 */

      ln_rg_number                   apps.ttec_taleo_stage.rgnumber%TYPE;   --Added for v6.6 --Vaitheghi
	  L_AUS_ADDL_ASG_DETL           VARCHAR2(100) DEFAULT NULL;             --Added for 8.6
	  L_AUS_JOB                     VARCHAR2(100) DEFAULT NULL;             --Added for 8.6

   BEGIN

        BEGIN
        fnd_global.apps_initialize(fnd_profile.value ('USER_ID') ,fnd_profile.value ('RESP_ID'),fnd_profile.value ('RESP_APPL_ID') );
        END;

      -- Output header information
      print_line ('');
      print_line (' TALEO INBOUND INTERFACE');
      print_line ('');
      print_line (   ' INTERFACE START TIMESTAMP = '
                  || TO_CHAR (SYSDATE, 'dd-mon-yy hh:mm:ss')
                 );
      print_line ('');

      print_line ('------------------------------');
      print_line ('TALEO EXCEPTION REPORT');
      print_line ('------------------------------');
      print_line ('');
      print_line
         ('Location             Candidate Reference Label   Reference Value     Error Message'
         );
      print_line
         ('--------             -------   ---------------   ---------------     -------------'
         );

     FOR r_hire IN c_hire LOOP

       BEGIN

            -- initialize global variables
            g_error_message                 := NULL;
            g_label1                        := 'Candidate ID';
            g_label2                        := NULL;
            g_label2                        := 'Location Code';
            g_module_name                   := 'main';
            g_primary_column                := r_hire.candidate_id;
            g_secondary_column              := NULL;
            g_recruiter_owner_employee_id   := r_hire.recruiter_owner_employee_id;
            g_recruiter_email_address       := r_hire.recruiter_email_address;

            g_action_type                   := NULL;
            g_location_name                 := NULL;

            -- initialize local variables
            l_success_flag                  := NULL;
            l_error_message                 := NULL;
            l_business_group_id             := NULL;
            l_security_group_id             := NULL;
            l_gender_code                   := NULL;

            l_ethnicity_code                := NULL;
            l_rehire_reason_code            := 'XXX';
            l_rehire_eligible               := NULL;
            l_leav_reason                   := NULL;
            l_final_process_date            := NULL;
            l_period_of_service_id          := NULL;
            l_ppos_object_version_number    := NULL;
            l_employee_number               := NULL;
            l_full_name                     := NULL;
            l_person_id                     := NULL;
            l_assignment_number             := NULL;
            l_asg_object_version_number     := NULL;
            l_assignment_id                 := NULL;
            l_location_id                   := NULL;

            l_gre_id                        := NULL;
            l_work_schedule_id              := NULL;
            l_payroll_id                    := NULL;
            l_job_id                        := NULL;
            l_pay_basis_id                  := NULL;
            l_timecard_approval             := NULL;
            l_organization_id               := NULL;
            l_county                        := NULL;
            l_start_date                    := NULL;
            l_dob_date                      := NULL;
            l_national_identifier           := NULL;
            l_marital_status                := NULL;
			L_AUS_ADDL_ASG_DETL             := NULL;     --Added for 8.6
			L_AUS_JOB                       := NULL;     --Added for 8.6

            -- set records processed counter
            l_records_read                  := l_records_read + 1;

            l_business_group_id             := TO_NUMBER(r_hire.business_group_id);
            l_npw_number                    := NULL;
            l_sys_per_type                  := r_hire.sys_per_type;
            l_person_type                   := r_hire.person_type;
            l_cwk_rate_type                 := r_hire.rate_type;
            l_agency_name                   := r_hire.agency_name;

            /* Version 1.4 - ZA Integration */
            l_registered_disabled_flag      := r_hire.disabled_veteran_id;
            l_study_level                   := r_hire.education_level;

            /* Version 1.5 - ARG Integration */
            l_addressdistrict               := r_hire.addressdistrict;
            l_addressneighborhood           := r_hire.addressneighborhood;
            l_addressmunicipality           := r_hire.addressmunicipality;
            l_sstype                        := r_hire.sstype;
            l_socialsecurityid              := r_hire.socialsecurityid;
            l_birthcountry                  := r_hire.birthcountry;
            l_stateprovincedes              := r_hire.stateprovincedes;

            /* Version 1.6.1 - MEX Integration */
            l_birthregion                   := r_hire.birthregion;
            l_birthtown                     := r_hire.birthtown;
            l_birthstate                    := r_hire.birthstate;
            l_unionaffiliation              := r_hire.unionaffiliation;
            l_industry                      := r_hire.industry;
            l_maternalname                  := r_hire.maternalname;
            l_ss_salary_type                := r_hire.ss_salary_type;
            l_contract_type                 := r_hire.contract_type;
            l_shift                         := r_hire.shift;
            l_workforce                     := r_hire.workforce;
            l_stateprovincecode             := r_hire.state;

            /* Version 5.0 - Motif India Integration */
            L_RESIDENTSTATUS                :=  r_hire.RESIDENTSTATUS;
            L_LIVEINADDRSINCE                :=  r_hire.LIVEINADDRSINCE;
            L_PANCARDNUMBER                    :=  r_hire.PANCARDNUMBER;
            L_PANCARDNAME                    :=  r_hire.PANCARDNAME;
            L_ADHARCARDNUMBER                :=  r_hire.ADHARCARDNUMBER;
            L_ADHARCARDNAME                    :=  r_hire.ADHARCARDNAME;
            L_VOTERID                        :=  r_hire.VOTERID;
            L_EPFNUMBER                        :=  r_hire.EPFNUMBER;
            L_UANNUMBER                        :=  r_hire.UANNUMBER;
            L_CORRESPADDRESS                :=  r_hire.CORRESPADDRESS;
            L_CORRESPADDRESS2                :=  r_hire.CORRESPADDRESS2;
            L_CORRESPCITY                    :=  r_hire.CORRESPCITY;
            L_CORRESPSTATE                    :=  r_hire.CORRESPSTATE;
            L_CORRESPZIPCODE                :=  r_hire.CORRESPZIPCODE;
            L_CORRESPCOUNTRYCODE            :=  r_hire.CORRESPCOUNTRYCODE;
            L_ARBITRATION_AGREEMENT         := r_hire.ARBITRATION_AGREEMENT; /* 6.3 */

            /* Version 1.6.2 - US Ethnic enhancement*/
            l_ethnic_disclosed              := r_hire.ethnic_disclosed;
            /* Version 1.8 -  ZA Visa Expiration Date enhancement */
            l_VisaExpirationDate            := r_hire.VisaExpirationDate;
            /* Version 1.9 --  Add Religion Capture Method to UK */
            l_fec_feedervalue               := r_hire.fec_feedervalue;
            l_rfc_id                        := r_hire.rfc_id; /* 3.5.3 */
			L_cpf_number                    := r_hire.cpf_number; /* 6.8 */

            ln_rg_number                    := null;--Added for v6.6 --Vaitheghi
            /* Version 1.3.2 - Updating Session_date */
            /* Added to avoid NI_VALIDATE fformula validation of UK NIN prefixes being rejected */
            UPDATE fnd_sessions
               SET effective_date = SYSDATE
             WHERE session_id = USERENV ('sessionid');

            IF SQL%ROWCOUNT = 0
            THEN
               INSERT INTO fnd_sessions
                           (session_id,
                            effective_date)
                    VALUES (USERENV ('sessionid'),
                            SYSDATE);
            END IF;
            /* End of version 1.3.2 */

            DBMS_OUTPUT.PUT_LINE ('1');

            -- National Identifier validation
            --
            IF     l_business_group_id IN (325, 326)
               AND r_hire.national_identifier IS NULL
            THEN
               g_error_message      := 'National Identifier is Null';
               g_label2             := 'Candidate';
               g_secondary_column   := r_hire.candidate_id;

               RAISE skip_record;
            END IF;

            DBMS_OUTPUT.PUT_LINE ('2');

            /* Set marital_status value according to the countries */
            IF l_business_group_id = 1517   -- PHL
            THEN
               l_marital_status := r_hire.Marital_Status_PH;

            ELSE
               l_marital_status := r_hire.Marital_Status_US;

            END IF;

            DBMS_OUTPUT.PUT_LINE ('3');

            -- format national identifier for US and Canada
            l_national_identifier := format_national_identifier
                                        (r_hire.national_identifier,
                                         l_business_group_id
                                         );
            DBMS_OUTPUT.PUT_LINE ('4');

            --get start date
            l_start_date        := TRUNC (r_hire.start_date);
            l_dob_date          := TRUNC (r_hire.date_of_birth);


            -- peo employee person type fix   ver 3.2
            IF l_person_type =  '692' THEN /* 3.3 */
               l_person_type_id    :=  692;
            ELSE
                          l_person_type_id    := get_person_type (l_business_group_id);
            END IF;


            g_location_name     := get_location_code(r_hire.location_id);

            fnd_file.put_line(fnd_file.output, 'Location'||','||g_location_name) ;

            /* Version 1.3 - ZA Integration */
            DBMS_OUTPUT.PUT_LINE ('5');

            IF l_business_group_id = 5054
            THEN
               l_organization_id := r_hire.organization_id;
              --IF r_hire.prg_flag = 'Y' THEN /* 7.0 Commented out */
              -- r_hire.country_code := 'CR'; -- v2.9 -- Commented as part of 7.7
              --END IF; /* 7.0 Commented out */
            END IF;
            /* End of Version 1.3 */

--8.6-Begin AU
            IF l_business_group_id = 1839 THEN
				BEGIN
					SELECT decode(attribute5,'Agent','38 hrs - Yes','38 hrs - Salaried'),
					       substr(name, instr(name, '.')+1,length(name))
						INTO L_AUS_ADDL_ASG_DETL, L_AUS_JOB
						FROM per_jobs
					WHERE job_id = r_hire.job_id
					  AND business_group_id = r_hire.business_group_id
					  AND date_from <= sysdate
				      AND ( ( date_to IS NULL ) OR ( date_to >= sysdate ) );

			    EXCEPTION
					WHEN OTHERS
					THEN
						    Fnd_File.put_line(Fnd_File.LOG, 'Error at getting Job and Additional ASG details: '||DBMS_UTILITY.FORMAT_ERROR_STACK );
							l_error_message     := SQLERRM;
							g_error_message    := 'Error employee creation' || SQLERRM;
							g_label2           := 'Candidate';
							g_secondary_column := r_hire.candidate_id;
							RAISE skip_record;
				END;
			END IF;
--8.6-End

            IF     r_hire.empl_is_rehire  =  1  --'Y'
            THEN
                g_action_type := 'REHIRE';
            ELSE
                g_action_type := 'CREATE';
            END IF;

    --        g_action_type := 'CREATE';


-----------------------------------------------------------------
            IF g_action_type = 'CREATE'
            THEN

                DBMS_OUTPUT.PUT_LINE ('before employee creation');
                -- person api

                DBMS_OUTPUT.PUT_LINE('sex:'||r_hire.sex);
                DBMS_OUTPUT.PUT_LINE('person_type: '||l_person_type_id);
                DBMS_OUTPUT.PUT_LINE('national'||l_national_identifier);
                DBMS_OUTPUT.PUT_LINE('ethnicity:'||r_hire.ethnicity);
                DBMS_OUTPUT.PUT_LINE('marital:'||l_marital_status);
                DBMS_OUTPUT.PUT_LINE('veteran:'||r_hire.veteran_id);
                DBMS_OUTPUT.PUT_LINE('business group:'||l_business_group_id);
                DBMS_OUTPUT.PUT_LINE('Citizenship:'||r_hire.citizenship);       -- Added as part of 8.1

                IF  NVL(l_sys_per_type,'XXX') <> 'CWK'
                THEN
                    create_employee (
                         p_business_group_id            => l_business_group_id,
                         p_hire_date                    => l_start_date,
                         p_attribute_category           => l_business_group_id,
                         p_pension_elig                 => TO_CHAR (l_start_date, 'RRRR/MM/DD'), --CA
                         p_candidate_id                 => r_hire.candidate_id,
                         p_title                                 => r_hire.title, /* 7.3.1 */
                         p_last_name                    => r_hire.last_name,
                         p_first_name                   => r_hire.first_name,
                         p_middle_names                 => r_hire.middle_names,
                         p_preferredname                => r_hire.PREFERREDNAME, /* 4.0.4 */
                         p_sex                          => r_hire.sex,
                         p_person_type_id               => l_person_type_id,
                         p_nationality                  => r_hire.nationality,
                         p_religion                     => r_hire.religion,
                         p_national_identifier          => l_national_identifier,
                         p_date_of_birth                => l_dob_date,
                         p_country                      => r_hire.country_code,
                         p_ethnicity                    => r_hire.ethnicity,
                         p_original_date_of_hire        => l_start_date,
                         p_marital_status               => l_marital_status,
                         p_email                        => r_hire.email,
                         p_veteran                      => r_hire.veteran_id,
                         p_legacy_emp_number            => r_hire.legacy_employee_number,
                         p_employee_number              => l_employee_number,
                         p_person_id                    => l_person_id,
                         p_assignment_number            => l_assignment_number,
                         p_asg_object_version_number    => l_asg_object_version_number,
                         p_assignment_id                => l_assignment_id,
                         p_full_name                    => l_full_name,
                         /* Version 1.4 - ZA Integration*/
                         p_organization_id              => l_organization_id,
                         p_registered_disabled_flag     => l_registered_disabled_flag,
                         p_user_person_type             => l_person_type,
                         /* Version 1.5 - ARG Integration*/
                         p_socialsecurityid             => l_socialsecurityid,
                         p_birthcountry                 => l_birthcountry,
                         p_sstype                       => l_sstype,
                         p_education_level              => l_study_level,
                         /* Version 1.6.1 - MEX Integration*/
                         p_region_of_birth              => l_birthregion,
                         p_state_of_birth               => l_birthstate,
                         p_maternal_last_name           => l_maternalname,
                         p_town_of_birth                => l_birthtown,
                         p_rfc_id                       => l_rfc_id, /* 3.5.3 */
                         /* Version 1.6.2 - US Ethnic enhancement*/
                         p_ethnic_disclosed             => l_ethnic_disclosed,
                         /* Version 1.8 - ZA Visa Expiration Date enhancement*/
                         p_VisaExpirationDate           => l_VisaExpirationDate,
                         /* Version 1.9 --  Add Religion Capture Method to UK */
                         p_capture_method               => l_fec_feedervalue,
                         --p_disabilitytype               => r_hire.disabilitytype /* 4.0.6 */
                        /* Version 5.0 - Motif India Integration*/
                         P_RESIDENTSTATUS               =>    L_RESIDENTSTATUS,
                         P_PANCARDNUMBER                =>    L_PANCARDNUMBER,
                         P_PANCARDNAME                  =>    L_PANCARDNAME,
                         P_ADHARCARDNUMBER              =>    L_ADHARCARDNUMBER,
                         P_ADHARCARDNAME                =>    L_ADHARCARDNAME,
                         P_VOTERID                      =>    L_VOTERID,
                         P_EPFNUMBER                    =>    L_EPFNUMBER,
                         P_UANNUMBER                    =>    L_UANNUMBER,
                         P_ARBITRATION_AGREEMENT        =>    L_ARBITRATION_AGREEMENT, /* 6.3 */
			             P_cpf_number                   =>    l_cpf_number, /* 6.8*/
                         p_AMKA                   =>    r_hire.AMKA,
                         p_AMA                    =>    r_hire.AMA,
                         p_IDENTITIY_CARD_NUM     =>    r_hire.IDENTITIY_CARD_NUM,
                         p_ee_enddate             =>    r_hire.EE_ENDDATE,
                         p_citizenship            =>    r_hire.citizenship,      -- Added as part of 8.1
                         p_tax_number             =>    r_hire.tax_number,        -- Added as part of 8.4
                         p_FLASTNAME             =>    r_hire.FLASTNAME,        -- Added as part of 8.5
                         p_MLASTNAME             =>    r_hire.MLASTNAME,        -- Added as part of 8.5
                         P_AUS_TAX_STATE         =>    l_stateprovincecode,     -- Added for 8.6
						 P_AUS_JOB               =>    L_AUS_JOB                -- Added for 8.6

                        );

                    DBMS_OUTPUT.PUT_LINE('person id:'||l_person_id);
                    DBMS_OUTPUT.PUT_LINE('employee number:'||l_employee_number);
                    DBMS_OUTPUT.PUT_LINE ('after employee creation');
                    DBMS_OUTPUT.PUT_LINE ('before stock');

                    g_employee_number := l_employee_number;

                    DBMS_OUTPUT.PUT_LINE('hire date:'||l_start_date);
                    DBMS_OUTPUT.PUT_LINE('options'||r_hire.stock_options);
                /*
                    -- Removing stock option as all stock grants are handled by Finance
                     IF l_business_group_id <> 1761 THEN  --Excluding UK
                      create_stock_options (
                        p_business_group_id  => l_business_group_id,
                        p_hire_date          => l_start_date,
                        p_effective_date     => l_start_date,
                        p_person_id          => l_person_id,
                        p_employee_number    => l_employee_number,
                        p_stock_options      => r_hire.stock_options  );
                     END IF;
                */
                        DBMS_OUTPUT.PUT_LINE ('after stock');
                        DBMS_OUTPUT.PUT_LINE ('before address');
                        --address api
                        -- create primary home address record

                 FND_FILE.PUT_LINE(fnd_file.output,'Address : ' ||','|| l_person_id||','||r_hire.country_code||',' ||r_hire.state) ;

                    /* Version 1.3 - ZA Integration */ /* Version 1.4 - ARG Integration */
                    create_address (p_business_group_id     => l_business_group_id,
                                   p_person_id              => l_person_id,
                                   p_effective_date         => l_start_date,
                                   p_style                  => r_hire.country_code,
                                   p_effective_start_date   => l_start_date,
                                   p_address_line1          => r_hire.address_line1,
                                   p_address_line2          => r_hire.address_line2,
                                   p_city                   => r_hire.city,
                                   p_region_1               => r_hire.county,
                                   p_region_2               => r_hire.state,
                                   p_postal_code            => r_hire.postal_code,
                                   p_country                => r_hire.country_code,
                                   p_landline               => r_hire.homephone,
                                   p_mobile                 => r_hire.mobilephone,
                                   p_email                  => r_hire.email,
                                   p_success_flag           => l_success_flag,
                                   p_error_message          => l_error_message,
                                   /* Version 1.3 - ZA Integration */
                                   p_organization_id        => l_organization_id,
                                   /* Version 1.4 - ARG Integration */
                                   p_stateprovincedes       => l_stateprovincedes,
								   p_stateprovincecode      => l_stateprovincecode,           --8.6
                                   p_addressdistrict        => l_addressdistrict,
                                   p_addressneighborhood    => l_addressneighborhood,
                                   p_addressmunicipality    => l_addressmunicipality,
                                   /* Version 5.0 Motif India Integration */
                                   P_LIVEINADDRSINCE        => r_hire.LIVEINADDRSINCE,
                                   P_CORRESPADDRESS         => r_hire.CORRESPADDRESS,
                                   P_CORRESPADDRESS2        => r_hire.CORRESPADDRESS2,
                                   P_CORRESPCITY            => r_hire.CORRESPCITY,
                                   P_CORRESPSTATE           => r_hire.CORRESPSTATE,
                                   P_CORRESPZIPCODE         => r_hire.CORRESPZIPCODE,
                                   P_CORRESPCOUNTRYCODE     => r_hire.CORRESPCOUNTRYCODE
                                   );
                    FND_FILE.PUT_LINE(fnd_file.output,'After Address : ' ||','|| l_person_id||','||r_hire.country_code||',' ||r_hire.state) ;
                    DBMS_OUTPUT.PUT_LINE ('after address');

                  --phone api
                  --create home phone record

                   DBMS_OUTPUT.PUT_LINE ('before phone');
                    IF r_hire.homephone IS NOT NULL
                    THEN
                        create_phone(l_person_id,
                                     l_start_date,
                                     'H1',
                                     r_hire.homephone);
                    END IF;

                  -- create work phone record
                    IF r_hire.workphone IS NOT NULL
                    THEN
                        create_phone (l_person_id,
                                      l_start_date,
                                      'W1',
                                      r_hire.workphone);
                    END IF;

                    -- create mobile phone record
                    IF r_hire.mobilephone IS NOT NULL
                    THEN
                        create_phone (l_person_id,
                                      l_start_date,
                                      'M',
                                      r_hire.mobilephone);
                    END IF;

                    DBMS_OUTPUT.PUT_LINE ('after phone');



               IF L_BUSINESS_GROUP_ID = 48558 THEN

                   IF r_hire.FLASTNAME IS NOT NULL or r_hire.MLASTNAME IS NOT NULL THEN

                       create_ind_parents_details( p_person_id              => l_person_id,
                                                   p_father_last_name       =>  r_hire.FLASTNAME,
                                                   p_father_middle_names    =>  r_hire.FMIDDLENAME,
                                                   p_father_first_name      =>  r_hire.FFIRSTNAME,
                                                   p_mother_last_name       =>  r_hire.MLASTNAME,
                                                   p_mother_middle_names    =>  r_hire.MMIDDLENAME,
                                                   p_mother_first_name      =>  r_hire.MFIRSTNAME);
                   END IF;

               END IF;

   IF (l_business_group_id = 5054)
               THEN

BEGIN
PL_COUNTRY_CODE:=NULL;

SELECT COUNTRY
INTO PL_COUNTRY_CODE
FROM APPS.HR_LOCATIONS_ALL HLA
WHERE HLA.LOCATION_ID =  r_hire.LOCATION_ID;
EXCEPTION
WHEN OTHERS
then
FND_FILE.PUT_LINE(FND_FILE.LOG,'Exception in retreiving the Country code through location id');

END;
         IF PL_COUNTRY_CODE = 'PL'
         THEN
                IF r_hire.POLAND_INDUSTRY_EXPERIENCE IS NOT NULL or r_hire.PL_REMAINING_BAL IS NOT NULL
                THEN

                        create_pl_experience_details(
                                                      p_business_group_id     => l_business_group_id,
                                                      p_person_id           => l_person_id,
                                                      p_effective_date     => l_start_date,
                                                      p_segment_1      =>  r_hire.POLAND_INDUSTRY_EXPERIENCE,
                                                      p_segment_2       =>  r_hire.PL_REMAINING_BAL
                                             );

                END IF;
             END IF;
           END IF;

               IF L_BUSINESS_GROUP_ID =  54749  THEN /* 7.3 */

                    IF r_hire.NUMBER_DEPENDENT_CHILD IS NOT NULL or r_hire.FLASTNAME IS NOT NULL or r_hire.MLASTNAME IS NOT NULL THEN /* 7.3.2 */
                         create_grc_dep_parents_details( p_person_id              => l_person_id,
                                                   p_no_dependant_child      =>  r_hire.NUMBER_DEPENDENT_CHILD,
                                                   p_father_last_name       =>  r_hire.FLASTNAME,
                                                   p_father_middle_names    =>  r_hire.FMIDDLENAME,
                                                   p_father_first_name      =>  r_hire.FFIRSTNAME,
                                                   p_mother_last_name       =>  r_hire.MLASTNAME,
                                                   p_mother_middle_names    =>  r_hire.MMIDDLENAME,
                                                   p_mother_first_name      =>  r_hire.MFIRSTNAME);
                    END IF;

                    IF r_hire.WORK_PERMIT_NUMBER IS NOT NULL or r_hire.WORK_PERMIT_EXPIRY_DATE  IS NOT NULL THEN /* 7.3.3 */
                         create_work_permit_details( p_person_id              => l_person_id,
                                                   p_work_permit_number              =>  r_hire.WORK_PERMIT_NUMBER ,
                                                   p_work_permit_expiry_date       =>  r_hire.WORK_PERMIT_EXPIRY_DATE );
                    END IF;

                    IF r_hire.PASSPORT_NUMBER IS NOT NULL or r_hire.PASSPORT_EXPIRY_DATE  IS NOT NULL THEN /* 7.3.4 */
                         create_passport_details( p_person_id              => l_person_id,
                                                   p_passport_number              =>  r_hire.PASSPORT_NUMBER ,
                                                   p_passport_expiry_date       =>  r_hire.PASSPORT_EXPIRY_DATE );
                    END IF;
                     /*ADDED BY RAJESH*/
                    IF r_hire.GREEK_FIRST_NAME IS NOT NULL or r_hire.GREEK_LAST_NAME  IS NOT NULL THEN /* 7.3.4 */
                         create_greek_name     ( p_person_id              => l_person_id,
                                                   p_greek_fn              =>  r_hire.GREEK_FIRST_NAME ,
                                                   p_greek_ln              =>  r_hire.GREEK_LAST_NAME );
                    END IF;

                     /*ADDED BY RAJESH*/
                   IF r_hire.ATTENDANCE_MODE IS NOT NULL
                   then
                         create_greek_att_mode     ( p_person_id              => l_person_id,
                                                   p_greek_att_mode           =>  r_hire.ATTENDANCE_MODE
                                                   );
                    END IF;

                  IF r_hire.WORKING_DAY_WEEK IS NOT NULL or r_hire.WORKING_ON_HOLIDAYS IS NOT NULL
                   then
                    create_greek_work_info    ( p_person_id              => l_person_id,
                                               p_work_on_holidays         =>  r_hire.WORKING_ON_HOLIDAYS,
                                                p_work_days_week        => r_hire.WORKING_DAY_WEEK
                                                );

                    END IF;


              /*ADDED BY RAJESH*/
                              create_grc_starttime (      p_business_group_id     => l_business_group_id,
                                                      p_person_id           => l_person_id,
                                                      p_effective_date     => l_start_date,
                                                      p_segment_1          =>  r_hire.START_TIME
                                                ); /* 7.3.5 */

                          create_grc_contract_end_date(
                             p_business_group_id     => l_business_group_id,
                                                      p_person_id           => l_person_id,
                                                      p_effective_date     => l_start_date,
                                                      p_segment_1          =>  r_hire.EE_ENDDATE --MAY BE WE NEED TO RE-NAME TO CONTRACT_ENDDATE
                              );

                    create_OEAD (      p_business_group_id     => l_business_group_id,
                                                      p_person_id           => l_person_id,
                                                      p_effective_date     => l_start_date,
                                                      p_segment_1          =>  r_hire.REFERENCE_NOTE_FROM_OAED,
                                                      p_segment_2          =>  r_hire.PROGRAM_PART_FINANCED_BY_OAED,
                                                      p_segment_3          =>  r_hire.RECEIVING_UNEMPL_BEN_BY_OAED,
													  p_segment_4          =>  r_hire.OAED_SPECIALITY_CODE
                                                ); /* 7.3.5 */

                    create_work_insurance (      p_business_group_id     => l_business_group_id,
                                                                       p_person_id           => l_person_id,
                                                                       p_effective_date     => l_start_date,
                                                                       p_segment_1          =>  r_hire.EXPERIENCE_START_DATE,
                                                                       p_segment_2          =>  r_hire.INSURED_BEFORE_AFTER_1993
                                                ); /* 7.3.6 */

                    create_grc_tax_auth_dept_DOY (      p_business_group_id     => l_business_group_id,
                                                                                       p_person_id           => l_person_id,
                                                                                       p_effective_date     => l_start_date,
                                                                                       p_segment_1          =>  r_hire.TAX_AUTHORITY_DEPARTMENT
                                                ); /* 7.3.7 */
               END IF;

                -- Match Point Enhancement
                  IF L_BUSINESS_GROUP_ID <> 1631
				     AND L_BUSINESS_GROUP_ID <> 1839 THEN         --Added 8.6

                      create_matchpoint(p_business_group_id     => l_business_group_id,
                                p_person_id         => l_person_id,
                                p_effective_date    => l_start_date,
                                p_segment_1          =>  r_hire.mp_source,
                                p_segment_2          =>  r_hire.mp_source_type,
                                p_segment_3          =>  r_hire.mp_batteryname,
                                p_segment_4          =>  r_hire.mp_batterylevel,
                                p_segment_5          =>  r_hire.mp_servicesimulation,
                                p_segment_6          =>  r_hire.mp_basiccomputerskills,
                                p_segment_7          =>  r_hire.mp_sales,
                                p_segment_8          =>  r_hire.mp_grammar,
                                p_segment_9          =>  r_hire.mp_adaptechsupport,
                                p_segment_10          =>  r_hire.mp_matrix,
                                p_segment_11          =>  r_hire.mp_fit,
                                p_segment_12          =>  r_hire.mp_ispsupport,
                                p_segment_13          =>  r_hire.mp_clt_assessment,
                                p_segment_14          =>  r_hire.mp_voice_score,
                                p_segment_15          =>  r_hire.mp_test_id,
                                p_segment_16          =>  r_hire.mp_listen,      /* Version 1.10 */
                                p_segment_17          =>  r_hire.mp_recruiter_id, /* Version 1.10 */
--                                p_segment_18          =>  r_hire.MP_CALLSIMULATIONADMINRECORDID,  /* Version 2.8 */ /* 3.4 */
--                                p_segment_19          =>  r_hire.MP_CALLSIMULATIONRESULTS,        /* Version 2.8 */ /* 3.4 */
--                                p_segment_20          =>  r_hire.MP_CIWAdministrator,             /* Version 2.8 */ /* 3.4 */
--                                p_segment_21          =>  r_hire.MP_CIWARESULT,                   /* Version 2.8 */ /* 3.4 */
                                p_segment_22          =>  r_hire.MP_Assessment_1,                  /* Version 3.0*/
                                p_segment_23          =>  r_hire.MP_Assessment_2,                  /* Version 3.0*/
                                p_segment_24          =>  r_hire.MP_Assessment_3,                  /* Version 3.0*/
                                p_segment_25          =>  r_hire.MP_Assessment_4,                  /* Version 3.0*/
                                p_segment_26          =>  r_hire.MP_Assessment_5,                  /* Version 3.0*/
                                p_segment_27          =>  r_hire.MP_Assessment_6,                  /* Version 3.0*/
                                p_segment_28          =>  r_hire.MP_Assessment_7,                  /* Version 3.0*/
                                p_segment_29          =>  r_hire.MP_Assessment_8,                  /* Version 3.0*/
                                p_segment_30          =>  r_hire.MP_Assessment_9                   /* Version 3.0*/
                                );
                      /* 3.4 */
                      create_hireiq(p_business_group_id     => l_business_group_id,
                                    p_person_id           => l_person_id,
                                    p_effective_date      => l_start_date,
                                    p_segment_1           =>  r_hire.MP_CALLSIMULATIONADMINRECORDID,
                                    p_segment_3           =>  r_hire.MP_CALLSIMULATIONRESULTS,
                                    p_segment_6           =>  r_hire.MP_CIWAdministrator,
                                    p_segment_9           =>  r_hire.MP_CIWARESULT,
                                    p_segment_12          =>  r_hire.HIQ_PACKAGE_ID,
                                    p_segment_15          =>  r_hire.HIQ_RATING,
                                    p_segment_18          =>  r_hire.HIQ_INTERVIEWER,
                                    p_segment_21          =>  r_hire.HIQ_SCORES);

                 END IF ;

                 /* Start changes for 8.3 */
                 IF (L_BUSINESS_GROUP_ID = 1633 AND
                    (r_hire.FISCAL_NAME IS NOT NULL OR
                    r_hire.FISCAL_ADD_ZIP IS NOT NULL OR
                    r_hire.FISCAL_REGIME_TYPE IS NOT NULL)) THEN

                    CREATE_FISCAL_SIT (   p_business_group_id     =>  l_business_group_id,
                                    p_person_id             =>  l_person_id,
                                    p_effective_date        =>  l_start_date,
                                    p_segment_1             =>  r_hire.FISCAL_NAME,
                                    p_segment_2             =>  r_hire.FISCAL_ADD_ZIP,
                                    p_segment_3             =>  r_hire.FISCAL_REGIME_TYPE
								);

                 END IF;
                 /* End changes for 8.3 */
                 fnd_file.put_line(fnd_file.output,'L_BUSINESS_GROUP_ID:'||L_BUSINESS_GROUP_ID||'l_organization_id:'||l_organization_id);
				 /* Start changes for 8.5 */
                 IF (apps.ttec_get_bg (L_BUSINESS_GROUP_ID, l_organization_id) = 67246 AND -- Change it to Columbia Business group
                    (
                    r_hire.CSI_ID_TYPE IS NOT NULL OR
                    r_hire.CSI_TAX_NUM IS NOT NULL OR
                    r_hire.CSI_FOREIGNER_NUM IS NOT NULL OR
                    r_hire.CSI_PASSPORT_NUM IS NOT NULL OR
                    r_hire.CSI_PASSPORT_COUNTRY IS NOT NULL OR
                    r_hire.CSI_ID_ISSUE_CITY IS NOT NULL OR
                    r_hire.CSI_ID_ISSUE_STATE IS NOT NULL OR
                    r_hire.CSI_EMPLOYMENT_CONTRACT IS NOT NULL OR
                    r_hire.Neighborhood IS NOT NULL OR
                    r_hire.Estrato IS NOT NULL OR
                    r_hire.Department_Code IS NOT NULL OR
                    r_hire.Municipality_Code IS NOT NULL OR
                    r_hire.NIT_EPS IS NOT NULL OR
                    r_hire.NIT_AFP IS NOT NULL OR
                    r_hire.GOV_JOB_OCCUPATION_CODE IS NOT NULL OR
                    r_hire.Workers_Activity_Code IS NOT NULL  OR
                    r_hire.CSI_CONTRACT_TYPE IS NOT NULL OR
                    r_hire.CSI_WEEKLY_DAYS IS NOT NULL OR
                    r_hire.CSI_ISSUE_DATE IS NOT NULL)
					)
					THEN

                    CREATE_COLUMBIA_SIT (   p_business_group_id     =>  l_business_group_id,
                                            p_person_id          =>  l_person_id,
                                            p_effective_date     =>  l_start_date,
                                            p_segment_1          =>  r_hire.CSI_ID_TYPE,
                                           -- p_segment_2          =>  NULL,  --- CSI_EMPLOYEE_ID
                                            p_segment_3          =>r_hire.CSI_TAX_NUM,
                                            p_segment_4          =>r_hire.CSI_FOREIGNER_NUM,
                                            p_segment_5          =>r_hire.CSI_PASSPORT_NUM,
                                            p_segment_6          =>r_hire.CSI_ID_ISSUE_CITY,
                                            p_segment_7          =>r_hire.CSI_ID_ISSUE_STATE,
                                            p_segment_8          =>r_hire.CSI_EMPLOYMENT_CONTRACT,
                                            p_segment_9          => r_hire.Neighborhood,
                                            p_segment_10          => r_hire.Estrato,
                                            p_segment_11         =>r_hire.Department_Code,
                                            p_segment_12         =>r_hire.Municipality_Code,
                                            p_segment_13         =>r_hire.NIT_EPS,
                                            p_segment_14         =>r_hire.NIT_AFP,
                                            p_segment_24         =>r_hire.GOV_JOB_OCCUPATION_CODE,
                                            p_segment_25         =>r_hire.Workers_Activity_Code,
                                            p_segment_26         =>r_hire.CSI_CONTRACT_TYPE,
                                            p_segment_27         =>r_hire.CSI_WEEKLY_DAYS,
                                            p_segment_28         =>r_hire.CSI_PASSPORT_COUNTRY,
                                            p_segment_29         =>r_hire.CSI_ISSUE_DATE
                                );
             fnd_file.put_line(fnd_file.output,'After create colombia SIT:');

                 END IF;
                 /* End changes for 8.5 */

                ELSE
                    DBMS_OUTPUT.PUT_LINE ('Create CWK ');
                    create_cwk(
                         p_business_group_id            => l_business_group_id,
                         p_hire_date                    => l_start_date,
                         p_candidate_id                 => r_hire.candidate_id,
                         p_person_type_id               => r_hire.person_type,
                         p_last_name                    => r_hire.last_name,
                         p_first_name                   => r_hire.first_name,
                         p_middle_names                 => r_hire.middle_names,
                         p_sex                          => r_hire.sex,
                         p_nationality                  => r_hire.nationality,
                         p_national_identifier          => l_national_identifier,
                         p_date_of_birth                => l_dob_date,
                         p_country                      => r_hire.country_code,
                         p_original_date_of_hire        => l_start_date,
                         p_marital_status               => l_marital_status,
                         p_email                        => r_hire.email,
                         p_npw_number                   => l_npw_number,
                         p_person_id                    => l_person_id,
                         p_assignment_number            => l_assignment_number,
                         p_asg_object_version_number    => l_asg_object_version_number,
                         p_assignment_id                => l_assignment_id,
                         p_full_name                    => l_full_name);

                    g_npw_number := l_npw_number;

                    DBMS_OUTPUT.PUT_LINE ('After create CWK ');

                END IF;
--------------------------------------------------------------
            ELSIF g_action_type = 'REHIRE'
            THEN
--------------------------------------------------------------
-- REHIRE  specific
----------------------------------------------------------------------------------
--REHIRE
--Final Process - Rehire - Employee(update) - Address(update) - Phone(update)

               --lookup
                get_rehire_person
                  (p_national_identifier            => REPLACE(REPLACE(l_national_identifier,' '),'-'),
                   p_business_group_id              => l_business_group_id,
                   p_start_date                     => l_start_date,
                   p_last_name                      => r_hire.last_name,
                   p_first_name                     => r_hire.first_name,
                   p_middle_names                   => r_hire.middle_names,
                   p_date_of_birth                  => l_dob_date,
                   p_sex                            => l_gender_code,
                   p_person_id                      => l_person_id,
                   p_per_object_version_number      => l_per_object_version_number,
                   p_employee_number                => l_employee_number,
                   p_leav_reason                    => l_leav_reason,
                   p_rehire_eligible                => l_rehire_eligible,
                   p_final_process_date             => l_final_process_date,
                   p_period_of_service_id           => l_period_of_service_id,
                   p_ppos_ovn                       => l_ppos_object_version_number,
                   p_full_name                      => l_full_name,
                   p_cpf_number                     => r_hire.cpf_number,   -- 2.6 brz
                   p_cpf_flag                       => r_hire.cpf_flag,
                   p_prg_flag                       => r_hire.prg_flag
                  );

                g_employee_number := l_employee_number;

               -- final process rehire eligible employee
               DBMS_OUTPUT.PUT_LINE ('Before final process');

               IF l_final_process_date IS NULL
               THEN
               -- FND_FILE.PUT_LINE (FND_FILE.OUTPUT, 'p_final_process_date'||l_start_date);
                  final_process_employee
                     (p_validate                   => FALSE,
                      p_business_group_id          => l_business_group_id,
                      p_employee_number            => l_employee_number,
                      p_period_of_service_id       => l_period_of_service_id,
                      p_object_version_number      => l_ppos_object_version_number,
                      p_final_process_date         => l_start_date - 1
                     );
               END IF;

               DBMS_OUTPUT.PUT_LINE ('After final process');
               DBMS_OUTPUT.PUT_LINE ('Before rehire');

               rehire_employee
                  (p_business_group_id              => l_business_group_id,
                   p_hire_date                      => l_start_date,
                   p_person_id                      => l_person_id,
                   p_per_object_version_number      => l_per_object_version_number,
                   p_reason_code                    => l_rehire_reason_code,
                   p_employee_number                => l_employee_number,
                   p_assignment_number              => l_assignment_number,
                   p_asg_object_version_number      => l_asg_object_version_number,
                   p_assignment_id                  => l_assignment_id
                  );

               DBMS_OUTPUT.PUT_LINE ('After rehire');

               DBMS_OUTPUT.PUT_LINE ('Rehired:' || l_employee_number);
               fnd_file.put_line(fnd_file.log, 'Rehired employee Number:'||l_employee_number) ;
               DBMS_OUTPUT.PUT_LINE ('Before Update Employee');
               fnd_file.put_line(fnd_file.log, 'Before Update Employee') ;
               fnd_file.put_line(fnd_file.log, 'Registered Disabled Flag - '||l_registered_disabled_flag) ;

               -- update_person
               update_employee (p_person_id                 => l_person_id,
                                p_business_group_id         => l_business_group_id,
                                p_hire_date                 => l_start_date,
                                p_pension_elig              => NULL,
                                p_candidate_id              => r_hire.candidate_id,
                                p_title                              => r_hire.title,       /* 7.3.1 */
                                p_last_name                 => r_hire.last_name,
                                p_first_name                => r_hire.first_name,
                                p_middle_names              => r_hire.middle_names,
                                p_preferredname             => r_hire.PREFERREDNAME, /* 4.0.4 */
                                p_sex                       => r_hire.sex,
                                p_person_type_id            => l_person_type_id,
                                p_date_of_birth             => l_dob_date,
                                p_country                   => r_hire.country_code,
                                p_ethnicity                 => r_hire.ethnicity,
                                p_marital_status            => l_marital_status,
                                p_veteran                   => r_hire.veteran_id,
                                p_email                     => r_hire.email,
                                p_nationality               => r_hire.nationality,
                                p_religion                  => r_hire.religion,
                                p_full_name                 => l_full_name,
                                /* Version 1.4 - ZA Integration */
                                p_organization_id           => l_organization_id,
                                p_registered_disabled_flag  => l_registered_disabled_flag,
                                /* Version 1.5 - ARG Integration */
                                p_education_level           => l_study_level,
                                /* Version 1.6.2 - US Ethnic enhancement*/
                                p_ethnic_disclosed          => l_ethnic_disclosed,
                                /* Version 1.7 - CR Integration */
                                p_birthcountry              => l_birthcountry,
                                /* Version 1.8 -  ZA Visa Expiration Date enhancement  */
                                p_VisaExpirationDate        => l_VisaExpirationDate,
                                /* Version 1.9 --  Add Religion Capture Method to UK */
                                p_capture_method            => l_fec_feedervalue,
                                /* Version 2.1  Begin */
                                p_region_of_birth           => l_birthregion,
                                p_state_of_birth            => l_birthstate,
                                p_maternal_last_name        => l_maternalname,
                                p_town_of_birth             => l_birthtown,
--                              /* Version 2.1  End */
                                /* Version 2.2  Begin */
                                p_socialsecurityid          => r_hire.socialsecurityid,
                                p_sstype                    => r_hire.sstype,
                                /* Version 2.2 End */
                                p_rfc_id                    => l_rfc_id, /* 3.5.3 */
                                --p_disabilitytype            => r_hire.disabilitytype /* 4.0.6 */
                                /* Version 5.0 - Motif India Integration*/
                                P_RESIDENTSTATUS            =>    L_RESIDENTSTATUS,
                                P_PANCARDNUMBER             =>    L_PANCARDNUMBER,
                                P_PANCARDNAME               =>    L_PANCARDNAME,
                                P_ADHARCARDNUMBER           =>    L_ADHARCARDNUMBER,
                                P_ADHARCARDNAME             =>    L_ADHARCARDNAME,
                                P_VOTERID                   =>    L_VOTERID,
                                P_EPFNUMBER                 =>    L_EPFNUMBER,
                                P_UANNUMBER                 =>    L_UANNUMBER,
                                P_ARBITRATION_AGREEMENT     =>    L_ARBITRATION_AGREEMENT, /* 6.3 */
								P_cpf_number                =>    L_cpf_number, /* 6.8 */
                                p_AMKA                   =>    r_hire.AMKA,
                                p_AMA                    =>    r_hire.AMA,
                                p_IDENTITIY_CARD_NUM     =>    r_hire.IDENTITIY_CARD_NUM,
                                p_ee_enddate             =>    r_hire.EE_ENDDATE,
                                p_citizenship            =>    r_hire.citizenship,       -- Added as part of 8.1
                                p_tax_number             =>    r_hire.tax_number,        -- Added as part of 8.4
                                p_FLASTNAME             =>    r_hire.FLASTNAME,        -- Added as part of 8.5
                                p_MLASTNAME             =>    r_hire.MLASTNAME,        -- Added as part of 8.5
								P_AUS_TAX_STATE         =>    l_stateprovincecode,     -- Added for 8.6
						        P_AUS_JOB               =>    L_AUS_JOB                -- Added for 8.6
                                );

               DBMS_OUTPUT.PUT_LINE ('After Update Employee');
               fnd_file.put_line(fnd_file.log, 'After Update Employee') ;

            /*
            --            Removing Stock grants as it is handled by Finance
                           DBMS_OUTPUT.PUT_LINE ('Before Update Stock Options');

                           IF l_business_group_id <> 1761 THEN  --Excluding UK
                           update_stock_options (
                                         p_business_group_id       => l_business_group_id,
                                         p_hire_date               => l_start_date,
                                         p_effective_date          => l_start_date,
                                         p_person_id               => l_person_id,
                                         p_employee_number         => l_employee_number,
                                         p_stock_options           => r_hire.stock_options
                                                     );
                           END IF;

                           DBMS_OUTPUT.PUT_LINE ('After Update Stock Options');
            */

               DBMS_OUTPUT.PUT_LINE ('Before Update Address');

               update_address (p_business_group_id         => l_business_group_id,
                               p_person_id                 => l_person_id,
                               p_employee_number           => l_employee_number,
                               p_effective_date            => l_start_date,
                               p_style                     => r_hire.country_code,
                               p_effective_start_date      => l_start_date,
                               p_address_line1             => r_hire.address_line1,
                               p_address_line2             => r_hire.address_line2,
                               p_city                      => r_hire.city,
                               p_region_1                  => r_hire.county,
                               p_region_2                  => r_hire.state,
                               p_postal_code               => r_hire.postal_code,
                               p_country                   => r_hire.country_code,
                               p_landline                  => r_hire.homephone,
                               p_mobile                    => r_hire.mobilephone,
                               p_email                     => r_hire.email,
                               /* Version 1.3 - ZA Integration */
                               p_organization_id           => l_organization_id,
                               /* Version 1.4 - ARG Integration */
                               p_stateprovincedes          => l_stateprovincedes,
							   p_stateprovincecode         => l_stateprovincecode,           --8.6
                               p_addressdistrict           => l_addressdistrict,
                               p_addressneighborhood       => l_addressneighborhood,
                               p_addressmunicipality       => l_addressmunicipality,
                               /* Version 5.0 Motif India Integration */
                               P_LIVEINADDRSINCE           => r_hire.LIVEINADDRSINCE,
                               P_CORRESPADDRESS            => r_hire.CORRESPADDRESS,
                               P_CORRESPADDRESS2           => r_hire.CORRESPADDRESS2,
                               P_CORRESPCITY               => r_hire.CORRESPCITY,
                               P_CORRESPZIPCODE            => r_hire.CORRESPZIPCODE,
                               P_CORRESPCOUNTRYCODE        => r_hire.CORRESPCOUNTRYCODE
                              );

               DBMS_OUTPUT.PUT_LINE ('After Update Address');
               DBMS_OUTPUT.PUT_LINE ('Before Update Home Phone');

               -- update phone
               IF r_hire.homephone IS NOT NULL
               THEN
                  update_phone (p_person_id            => l_person_id,
                                p_employee_number      => l_employee_number,
                                p_effective_date       => l_start_date,
                                p_phone_type           => 'H1',
                                p_phone_number         => r_hire.homephone
                               );
               END IF;

               DBMS_OUTPUT.PUT_LINE ('After Update Home Phone');

               DBMS_OUTPUT.PUT_LINE ('Before Update Work Phone');

               IF r_hire.workphone IS NOT NULL
               THEN
                  update_phone (p_person_id            => l_person_id,
                                p_employee_number      => l_employee_number,
                                p_effective_date       => l_start_date,
                                p_phone_type           => 'W1',
                                p_phone_number         => r_hire.workphone
                               );
               END IF;

               DBMS_OUTPUT.PUT_LINE ('After Update Work Phone');

               DBMS_OUTPUT.PUT_LINE ('Before Update Mobile Phone');

               IF r_hire.mobilephone IS NOT NULL
               THEN
                  update_phone (p_person_id            => l_person_id,
                                p_employee_number      => l_employee_number,
                                p_effective_date       => l_start_date,
                                p_phone_type           => 'M',
                                p_phone_number         => r_hire.mobilephone /* 2.2 */
                               );
               END IF;

               DBMS_OUTPUT.PUT_LINE ('After Update Mobile Phone');

               IF L_BUSINESS_GROUP_ID = 48558 THEN

                   IF r_hire.FLASTNAME IS NOT NULL or r_hire.MLASTNAME IS NOT NULL THEN
                       update_ind_parents_details( p_person_id     => l_person_id,
                                          p_father_last_name       =>  r_hire.FLASTNAME,
                                          p_father_middle_names    =>  r_hire.FMIDDLENAME,
                                          p_father_first_name      =>  r_hire.FFIRSTNAME,
                                          p_mother_last_name       =>  r_hire.MLASTNAME,
                                          p_mother_middle_names    =>  r_hire.MMIDDLENAME,
                                          p_mother_first_name      =>  r_hire.MFIRSTNAME);
                   END IF;
               END IF;

              IF (l_business_group_id = 5054)
               THEN
BEGIN
PL_COUNTRY_CODE:=NULL;

SELECT COUNTRY
INTO PL_COUNTRY_CODE
FROM APPS.HR_LOCATIONS_ALL HLA
WHERE HLA.LOCATION_ID =  r_hire.LOCATION_ID;

EXCEPTION
WHEN OTHERS
THEN
FND_FILE.PUT_LINE(FND_FILE.LOG,'Exception in retreiving the Country code through location id');

END;

       IF PL_COUNTRY_CODE = 'PL'
         THEN
                IF r_hire.POLAND_INDUSTRY_EXPERIENCE IS NOT NULL or r_hire.PL_REMAINING_BAL IS NOT NULL
                THEN

                        update_pl_experience_details(
                                                      p_business_group_id     => l_business_group_id,
                                                      p_person_id           => l_person_id,
                                                      p_employee_number    => l_employee_number,
                                                      p_effective_date     => l_start_date,
                                                      p_segment_1      =>  r_hire.POLAND_INDUSTRY_EXPERIENCE,
                                                      p_segment_2       =>  r_hire.PL_REMAINING_BAL
                                             );

                END IF;
              END IF;
           END IF;

               IF L_BUSINESS_GROUP_ID =  54749  THEN /* 7.3 */

                    IF r_hire.NUMBER_DEPENDENT_CHILD IS NOT NULL or r_hire.FLASTNAME IS NOT NULL or r_hire.MLASTNAME IS NOT NULL THEN /* 7.3.2 */
                        update_grc_dep_parents_details( p_person_id              => l_person_id,
                                                   p_no_dependant_child      =>  r_hire.NUMBER_DEPENDENT_CHILD,
                                                   p_father_last_name       =>  r_hire.FLASTNAME,
                                                   p_father_middle_names    =>  r_hire.FMIDDLENAME,
                                                   p_father_first_name      =>  r_hire.FFIRSTNAME,
                                                   p_mother_last_name       =>  r_hire.MLASTNAME,
                                                   p_mother_middle_names    =>  r_hire.MMIDDLENAME,
                                                   p_mother_first_name      =>  r_hire.MFIRSTNAME);
                    END IF;

                    IF r_hire.WORK_PERMIT_NUMBER IS NOT NULL or r_hire.WORK_PERMIT_EXPIRY_DATE  IS NOT NULL THEN /* 7.3.3 */
                         update_work_permit_details( p_person_id              => l_person_id,
                                                   p_work_permit_number              =>  r_hire.WORK_PERMIT_NUMBER ,
                                                   p_work_permit_expiry_date       =>  r_hire.WORK_PERMIT_EXPIRY_DATE );
                    END IF;

                    IF r_hire.PASSPORT_NUMBER IS NOT NULL or r_hire.PASSPORT_EXPIRY_DATE  IS NOT NULL THEN /* 7.3.4 */
                         update_passport_details( p_person_id              => l_person_id,
                                                   p_passport_number              =>  r_hire.PASSPORT_NUMBER ,
                                                   p_passport_expiry_date       =>  r_hire.PASSPORT_EXPIRY_DATE );
                    END IF;

                   /*ADDED BY RAJESH*/
                    IF r_hire.GREEK_FIRST_NAME IS NOT NULL or r_hire.GREEK_LAST_NAME  IS NOT NULL THEN /* 7.3.4 */
                         update_greek_name     ( p_person_id              => l_person_id,
                                                   p_greek_fn              =>  r_hire.GREEK_FIRST_NAME ,
                                                   p_greek_ln              =>  r_hire.GREEK_LAST_NAME );
                    END IF;

                     /*ADDED BY RAJESH*/
                   IF r_hire.ATTENDANCE_MODE IS NOT NULL
                   then
                         update_greek_att_mode     ( p_person_id              => l_person_id,
                                                   p_greek_att_mode           =>  r_hire.ATTENDANCE_MODE
                                                   );
                    END IF;

                  IF r_hire.WORKING_DAY_WEEK IS NOT NULL or r_hire.WORKING_ON_HOLIDAYS IS NOT NULL
                   then
                    update_greek_work_info    ( p_person_id              => l_person_id,
                                                p_work_on_holidays         =>  r_hire.WORKING_ON_HOLIDAYS,
                                                p_work_days_week        => r_hire.WORKING_DAY_WEEK
                                                );
                    END IF;


              /*ADDED BY RAJESH*/
                              update_grc_starttime (      p_business_group_id     => l_business_group_id,
                                                      p_person_id           => l_person_id,
                                                      p_employee_number    => l_employee_number,
                                                      p_effective_date     => l_start_date,
                                                      p_segment_1          =>  r_hire.START_TIME
                                                ); /* 7.3.5 */

                          update_grc_contract_end_date(
                                                      p_business_group_id     => l_business_group_id,
                                                      p_person_id           => l_person_id,
                                                      p_employee_number    => l_employee_number,
                                                      p_effective_date     => l_start_date,
                                                      p_segment_1          =>  r_hire.EE_ENDDATE --MAY BE WE NEED TO RE-NAME TO CONTRACT_ENDDATE
                              );

                   update_OEAD (      p_business_group_id     => l_business_group_id,
                                                      p_person_id           => l_person_id,
                                                      p_employee_number    => l_employee_number,
                                                      p_effective_date     => l_start_date,
                                                      p_segment_1          =>  r_hire.REFERENCE_NOTE_FROM_OAED,
                                                      p_segment_2          =>  r_hire.PROGRAM_PART_FINANCED_BY_OAED,
                                                      p_segment_3          =>  r_hire.RECEIVING_UNEMPL_BEN_BY_OAED,
													  p_segment_4          =>  r_hire.OAED_SPECIALITY_CODE
                                                ); /* 7.3.5 */

                   update_work_insurance (      p_business_group_id     => l_business_group_id,
                                                                       p_person_id                       => l_person_id,
                                                                       p_employee_number       => l_employee_number,
                                                                       p_effective_date              => l_start_date,
                                                                       p_segment_1                    => r_hire.EXPERIENCE_START_DATE,
                                                                       p_segment_2                    =>  r_hire.INSURED_BEFORE_AFTER_1993
                                                                 ); /* 7.3.6 */

                   update_grc_tax_auth_dept_DOY (     p_business_group_id     => l_business_group_id,
                                                                                       p_person_id                     => l_person_id,
                                                                                       p_employee_number    => l_employee_number,
                                                                                       p_effective_date     => l_start_date,
                                                                                       p_segment_1          =>  r_hire.TAX_AUTHORITY_DEPARTMENT
                                                                                 ); /* 7.3.7 */
               END IF;

                     /* Version 1.10 Commented out By C. Chan */
                    /*      update_matchpoint( p_person_id            => l_person_id,
                                           p_employee_number      => l_employee_number,
                                           p_effective_date       => l_start_date);
                     */
                   if l_business_group_id <> 1631  /* 7.9 */
				      AND L_BUSINESS_GROUP_ID <> 1839 THEN         --Added 8.6
                    -- if l_business_group_id not in (1631) then /* 7.9 */
                      update_matchpoint(p_business_group_id     => l_business_group_id,
                                p_person_id          => l_person_id,
                                p_employee_number    => l_employee_number,
                                p_effective_date     => l_start_date,
                                p_segment_1          =>  r_hire.mp_source,
                                p_segment_2          =>  r_hire.mp_source_type,
                                p_segment_3          =>  r_hire.mp_batteryname,
                                p_segment_4          =>  r_hire.mp_batterylevel,
                                p_segment_5          =>  r_hire.mp_servicesimulation,
                                p_segment_6          =>  r_hire.mp_basiccomputerskills,
                                p_segment_7          =>  r_hire.mp_sales,
                                p_segment_8          =>  r_hire.mp_grammar,
                                p_segment_9          =>  r_hire.mp_adaptechsupport,
                                p_segment_10          =>  r_hire.mp_matrix,
                                p_segment_11          =>  r_hire.mp_fit,
                                p_segment_12          =>  r_hire.mp_ispsupport,
                                p_segment_13          =>  r_hire.mp_clt_assessment,
                                p_segment_14          =>  r_hire.mp_voice_score,
                                p_segment_15          =>  r_hire.mp_test_id,
                                p_segment_16          =>  r_hire.mp_listen,      /* Version 1.10 */
                                p_segment_17          =>  r_hire.mp_recruiter_id, /* Version 1.10 */
--                                p_segment_18          =>  r_hire.MP_CALLSIMULATIONADMINRECORDID,  /* Version 2.8 */
--                                p_segment_19          =>  r_hire.MP_CALLSIMULATIONRESULTS,         /* Version 2.8 */
--                                p_segment_20          =>  r_hire.MP_CIWAdministrator,             /* Version 2.8 */
--                                p_segment_21          =>  r_hire.MP_CIWARESULT,                   /* Version 2.8 */
                                p_segment_22          =>  r_hire.MP_Assessment_1,                  /* Version 3.0 */
                                p_segment_23          =>  r_hire.MP_Assessment_2,                  /* Version 3.0 */
                                p_segment_24          =>  r_hire.MP_Assessment_3,                  /* Version 3.0 */
                                p_segment_25          =>  r_hire.MP_Assessment_4,                  /* Version 3.0 */
                                p_segment_26          =>  r_hire.MP_Assessment_5,                  /* Version 3.0 */
                                p_segment_27          =>  r_hire.MP_Assessment_6,                  /* Version 3.0 */
                                p_segment_28          =>  r_hire.MP_Assessment_7,                  /* Version 3.0 */
                                p_segment_29          =>  r_hire.MP_Assessment_8,                  /* Version 3.0 */
                                p_segment_30          =>  r_hire.MP_Assessment_9                  /* Version 3.0 */
                             );
                      /* 3.4 */
                      update_hireiq(p_business_group_id   => l_business_group_id,
                                    p_person_id           => l_person_id,
                                    p_employee_number     => l_employee_number,
                                    p_effective_date      => l_start_date,
                                    p_segment_1           =>  r_hire.MP_CALLSIMULATIONADMINRECORDID,
                                    p_segment_3           =>  r_hire.MP_CALLSIMULATIONRESULTS,
                                    p_segment_6           =>  r_hire.MP_CIWAdministrator,
                                    p_segment_9           =>  r_hire.MP_CIWARESULT,
                                    p_segment_12          =>  r_hire.HIQ_PACKAGE_ID,
                                    p_segment_15          =>  r_hire.HIQ_RATING,
                                    p_segment_18          =>  r_hire.HIQ_INTERVIEWER,
                                    p_segment_21          =>  r_hire.HIQ_SCORES
                             );

                   end  if;

                /* Start changes for 8.3 */
                 IF (L_BUSINESS_GROUP_ID = 1633 AND
                    (r_hire.FISCAL_NAME IS NOT NULL OR
                    r_hire.FISCAL_ADD_ZIP IS NOT NULL OR
                    r_hire.FISCAL_REGIME_TYPE IS NOT NULL)) THEN

                    UPDATE_FISCAL_SIT (   p_business_group_id     =>  l_business_group_id,
                                    p_person_id             =>  l_person_id,
                                    p_employee_number       =>  l_employee_number,
                                    p_effective_date        =>  l_start_date,
                                    p_segment_1             =>  r_hire.FISCAL_NAME,
                                    p_segment_2             =>  r_hire.FISCAL_ADD_ZIP,
                                    p_segment_3             =>  r_hire.FISCAL_REGIME_TYPE
								);

                 END IF;
                 /* End changes for 8.3 */

				 /* Start changes for 8.5 */
                 IF (apps.ttec_get_bg (L_BUSINESS_GROUP_ID, l_organization_id) = 67246 AND -- Change the Business group id for Columbia
                    					(
                    r_hire.CSI_ID_TYPE IS NOT NULL OR
                    r_hire.CSI_TAX_NUM IS NOT NULL OR
                    r_hire.CSI_FOREIGNER_NUM IS NOT NULL OR
                    r_hire.CSI_PASSPORT_NUM IS NOT NULL OR
                    r_hire.CSI_PASSPORT_COUNTRY IS NOT NULL OR
                    r_hire.CSI_ID_ISSUE_CITY IS NOT NULL OR
                    r_hire.CSI_ID_ISSUE_STATE IS NOT NULL OR
                    r_hire.CSI_EMPLOYMENT_CONTRACT IS NOT NULL OR
                    r_hire.Neighborhood IS NOT NULL OR
                    r_hire.Estrato IS NOT NULL OR
                    r_hire.Department_Code IS NOT NULL OR
                    r_hire.Municipality_Code IS NOT NULL OR
                    r_hire.NIT_EPS IS NOT NULL OR
                    r_hire.NIT_AFP IS NOT NULL OR
                    r_hire.GOV_JOB_OCCUPATION_CODE IS NOT NULL OR
                    r_hire.Workers_Activity_Code IS NOT NULL OR
                    r_hire.CSI_CONTRACT_TYPE IS NOT NULL OR
                    r_hire.CSI_WEEKLY_DAYS IS NOT NULL OR
                    r_hire.CSI_ISSUE_DATE IS NOT NULL
                    )
					) THEN

                    UPDATE_COLUMBIA_SIT (p_business_group_id     =>  l_business_group_id,
                                            p_person_id          =>  l_person_id,
                                            p_employee_number    =>  l_employee_number,
                                            p_effective_date     =>  l_start_date,
                                            p_segment_1          =>  r_hire.CSI_ID_TYPE,
                                          --  p_segment_2          =>  NULL,  --- CSI_EMPLOYEE_ID
                                            p_segment_3          =>r_hire.CSI_TAX_NUM,
                                            p_segment_4          =>r_hire.CSI_FOREIGNER_NUM,
                                            p_segment_5          =>r_hire.CSI_PASSPORT_NUM,
                                            p_segment_6          =>r_hire.CSI_ID_ISSUE_CITY,
                                            p_segment_7          =>r_hire.CSI_ID_ISSUE_STATE,
                                            p_segment_8          =>r_hire.CSI_EMPLOYMENT_CONTRACT,
                                            p_segment_9          => r_hire.Neighborhood,
                                            p_segment_10          => r_hire.Estrato,
                                            p_segment_11         =>r_hire.Department_Code,
                                            p_segment_12         =>r_hire.Municipality_Code,
                                            p_segment_13         =>r_hire.NIT_EPS,
                                            p_segment_14         =>r_hire.NIT_AFP,
                                            p_segment_24         =>r_hire.GOV_JOB_OCCUPATION_CODE,
                                            p_segment_25         =>r_hire.Workers_Activity_Code,
                                            p_segment_26         =>r_hire.CSI_CONTRACT_TYPE,
                                            p_segment_27         =>r_hire.CSI_WEEKLY_DAYS,
                                            p_segment_28         =>r_hire.CSI_PASSPORT_COUNTRY,
                                            p_segment_29         =>r_hire.CSI_ISSUE_DATE
                                );

                 END IF;
                 /* End changes for 8.5 */
--------------------------------------------------------------
            END IF; ---action type
-------------------COMMON API's-------------------------------

            l_employment_category := r_hire.assignment_category_code;
            IF  NVL(l_sys_per_type,'XXX') <> 'CWK'
            THEN
                l_work_schedule_id := get_work_schedule(l_business_group_id);

                DBMS_OUTPUT.PUT_LINE ('before assignment');
                  DBMS_OUTPUT.PUT_LINE ('business group:'||l_business_group_id);

                /* Version 1.3 - ZA Integration */ /* Version 1.4 - ARG Integration */
                update_assignment
                      (p_datetrack_mode                 => 'CORRECTION',
                       p_effective_date                 => l_start_date,
                       p_assignment_id                  => l_assignment_id,
                       p_object_version_number          => l_asg_object_version_number,
                       p_business_group_id              => l_business_group_id,
                       p_people_group_id                => r_hire.people_group_id,
                       p_job_id                         => r_hire.job_id,
                       p_grade_id                       => r_hire.grade_id,
                       p_payroll_id                     => r_hire.payroll_id,
                       p_location_id                    => r_hire.location_id,
                       p_organization_id                => r_hire.organization_id,
                       p_pay_basis_id                   => r_hire.salary_basis_id,
                       p_employment_category            => l_employment_category,
                       p_supervisor_id                  => r_hire.supervisor_id,
                       p_tax_unit_id                    => r_hire.gre_id,
                       p_timecard_required              => r_hire.timecard_required,
                       p_work_schedule                  => l_work_schedule_id,
                       p_normal_hours                   => r_hire.normal_hours,
                       p_frequency                      => r_hire.frequency,
                       p_set_of_books_id                => r_hire.set_of_books_id,
                       p_expense_account_id             => r_hire.expense_account_id,
                       p_probation_period               => r_hire.probation_length,
                       p_probation_unit                 => r_hire.probation_units,
                       p_date_probation_end             => r_hire.probation_end_date,
                       p_work_at_home                   => r_hire.working_at_home_flag,
                       p_employee_category              => r_hire.employee_category,
                       p_sal_review_period              => r_hire.review_salary,
                       p_sal_review_period_frequency    => r_hire.review_salary_frequency,
                       p_perf_review_period             => r_hire.review_performance,
                       p_perf_review_period_frequency   => r_hire.review_performance_frequency,
                       /* Version 1.3 - ZA Integration */
                       p_education_level                => r_hire.education_level,
                       p_ethnicity                      => r_hire.ethnicity,
                       p_nationality                    => r_hire.nationality,
                       /* Version 1.4 - ARG Integration */
                       p_industry                       => r_hire.industry,
                       p_unionaffiliation               => r_hire.unionaffiliation,
                       /* Version 1.6.1 - MEX Integration */
                       p_ss_salary_type                 => r_hire.ss_salary_type,    -- Social Security Salary Type
                       p_shift_id                       => r_hire.shift,
                       p_contract_start_dt              => r_hire.contract_start_dt,
                       p_contract_type                  => r_hire.contract_type,
                       p_employee_type                  => r_hire.workforce,
                     /* Version 1.7 - Costa Rica Integration*/
                       p_LanguageDifferential           => r_hire.LanguageDifferential,
                       p_ANNUALTENUREPAY                => r_hire.ANNUALTENUREPAY, /* 7.0 */
                       p_WORK_ARRANGEMENT               => r_hire.WORK_ARRANGEMENT,        /* 7.2 */
                       p_WORK_ARRANGEMENT_REASON        => r_hire.WORK_ARRANGEMENT_REASON /* 7.2 */
                      ,P_BULG_EMP_CODE                  => r_hire.BULG_EMP_CODE,
					   P_TECH_SOLN                      => r_hire.TECH_SOLN,     -- Added as part of 7.9
                       P_AUS_ADDL_ASG_DETL              => L_AUS_ADDL_ASG_DETL,  -- Added as part of 8.6
					   P_AUS_JOB                        => L_AUS_JOB,            -- Added as part of 8.6
					   P_MEX_SODEXO_LOC                 => r_hire.MEX_SODEXO_LOC      -- Added as part of 8.7


      -- Output parameters
                       );
            IF l_business_group_id = 1631 THEN              --2.6 BRZ TALEO INEGRATION

                  /* 4.0.7.1 begin */
                  IF  r_hire.FLASTNAME IS NOT NULL THEN
                        update_contact_relationship (
                              p_start_date             => l_start_date,
                              p_person_id              => l_person_id,
                              p_business_group_id      => r_hire.business_group_id,
                              p_sex                    => 'M',
                              p_last_name              => r_hire.FLASTNAME,
                              p_first_name             => r_hire.FFIRSTNAME, --r_hire.FMIDDLENAME, --Modified for v6.7
                              p_middle_names           => r_hire.FMIDDLENAME, --r_hire.FFIRSTNAME, --Modified for v6.7
                              p_contact_type           => 'JP_FT');
                              --p_contact_type           => 'P');
                  END IF;
                  /* 4.0.7.1 End */

                  /* 4.0.7.2 begin */
                  IF  r_hire.MLASTNAME IS NOT NULL THEN
                        update_contact_relationship (
                              p_start_date             => l_start_date,
                              p_person_id              => l_person_id,
                              p_business_group_id      => r_hire.business_group_id,
                              p_sex                    => 'F',
                              p_last_name              => r_hire.MLASTNAME,
                              p_first_name             => r_hire.MFIRSTNAME, --r_hire.MMIDDLENAME, --Modified for v6.7
                              p_middle_names           => r_hire.MMIDDLENAME, --r_hire.MFIRSTNAME, --Modified for v6.7
                              p_contact_type           => 'JP_MT');
                              --p_contact_type           => 'P');
                  END IF;
                  /* 4.0.7.2 End */
                ln_rg_number := REGEXP_REPLACE(r_hire.RGNumber,'[^0-9]+', ''); --Added for v6.6 --Vaitheghi
                 Create_CLL_Data (
                          P_action_type => g_action_type,
                           P_Person_id    => l_person_id ,
                           P_CPF_NUMBER   => r_hire.CPF_NUMBER,
                           P_CTPS_NUMBER => r_hire.CTPS_NUMBER,
                           P_CTPS_ISSUE_DATE => r_hire.CTPS_ISSUE_DATE,
                           P_CTPSSerialNumber => r_hire.CTPSSerialNumber,
                           P_PIS         => r_hire.PIS,
                           P_PISBankNumber => r_hire.PISBankNumber,
                           P_PISIssueDate => r_hire.PISIssueDate,
                           P_PISProgramType=> r_hire.PISProgramType,
                           P_RGExpeditingDate => r_hire.RGExpeditingDate,
                           P_RGExpeditorEntity => r_hire.RGExpeditorEntity,
                           P_RGLocation  => r_hire.RGLocation,
                           P_RGState   => r_hire.RGState,
                           P_RGNumber    => ln_rg_number, --r_hire.RGNumber, --Modified for v6.6 --Vaitheghi
                           P_VoterRegistrationCard => r_hire.VOTERREGISTRATIONCARD,
                           P_VRCSession  => r_hire.VRCSession,
                           P_VRCState    => r_hire.VRCState,
                           P_VRCZone    => r_hire.VRCZone ,
                           P_CPF_FLAG  => r_hire.cpf_flag,
                           P_EDUCATION_LEVEL => r_hire.education_level, /* 4.0.3 */
                           P_DISABLED_PERSON => r_hire.DISABILITY, /* 4.0.6 */
                           P_FIRSTEMPLOYMENT => r_hire.FIRSTEMPLOYMENT, /* 4.0.8 */
                           P_RETIRED => r_hire.RETIRED, /* 4.0.9 */
                           P_RETIREDCODE => r_hire.RETIREDCODE, /* 4.0.9 */
                           P_RETIREMENTDATE  => r_hire.RETIREMENTDATE , /* 4.0.9 */
                           P_MILITARYDISCHARGE  => r_hire.MILITARYDISCHARGE , /* 4.0.10 */
                           P_effective_date => l_start_date ) ;


             END IF ;

                --create salary

                DBMS_OUTPUT.PUT_LINE ('After Update Assignment');
                --create costing
            -- /* 6.0 */ IF l_business_group_id <> 1631 THEN   --2.6 BRZ TALEO INEGRATION

                   DBMS_OUTPUT.PUT_LINE ('Before Costing');

                create_costing (
                        p_effective_date         => l_start_date,
                        p_assignment_id          => l_assignment_id,
                        p_business_group_id      => l_business_group_id,
                        p_proportion             => 1,
                        p_segment1               => r_hire.gl_location_override, -- Version 2.0
                        p_segment2               => r_hire.client_code
                       );
                   DBMS_OUTPUT.PUT_LINE ('After Costing');
            -- /* 6.0 */    END IF;

                DBMS_OUTPUT.PUT_LINE ('Before Bill');
                -- Bill At Will

                -- custom table
                create_bill_at_will(
                     p_person_id            => l_person_id,
                     p_employee_number      => l_employee_number,
                     p_client_code          => r_hire.client_code,
                     p_client_desc          => r_hire.client_desc,
                     p_program              => r_hire.program,
                     p_program_desc         => r_hire.program_desc,
                     p_project              => r_hire.project,
                     p_project_desc         => r_hire.project_desc,
                     p_project_start        => l_start_date,
                     p_project_end          => g_oracle_end_date,
                     p_full_name            => l_full_name,
                     p_business_group_id    => l_business_group_id,
                     p_location_id          => r_hire.location_id,
                     p_emp_type             => 'Employee');


                DBMS_OUTPUT.PUT_LINE ('After Bill');



        --/ * 6.2 */     IF L_BUSINESS_GROUP_ID <> 48558 THEN /* 6.0 Motif India Integration */

                    DBMS_OUTPUT.PUT_LINE ('Before Salary');
                    create_salary (
                                p_effective_date         => l_start_date,
                                p_assignment_id          => l_assignment_id,
                                p_business_group_id      => l_business_group_id,
                                p_proposed_salary_n      => r_hire.salary,
                                p_approved               => 'Y');

                    DBMS_OUTPUT.PUT_LINE ('After Salary');
         --/ * 6.2 */      END IF;

             --IF l_business_group_id <> 1631 THEN   --2.6 BRZ TALEO INEGRATION
             IF l_business_group_id NOT IN  (  1631   -- 2.6 BRZ TALEO INEGRATION
                                             , 48558  -- 6.0 Motif India TALEO Integration
                                            )
             THEN

                DBMS_OUTPUT.PUT_LINE ('Before SUI Update');
                update_sui_state  (
                            p_business_group_id  => l_business_group_id,
                            p_person_id          => l_person_id,
                            p_assignment_id      => l_assignment_id,
                            p_effective_date     => l_start_date,
                            p_work_at_home       => r_hire.working_at_home_flag);

                DBMS_OUTPUT.PUT_LINE ('After SUI Update');
                DBMS_OUTPUT.PUT_LINE ('Before CAN SUI Update');

                create_ca_sui_state (
                          p_business_group_id    => l_business_group_id,
                          p_person_id            => l_person_id,
                          p_assignment_id        => l_assignment_id,
                          p_effective_date       => l_start_date,
                          p_work_at_home         => r_hire.working_at_home_flag );


                DBMS_OUTPUT.PUT_LINE ('After CAN SUI Update');
              END IF ;   --2.6 BRZ TALEO INEGRATION

            ELSE
                  fnd_file.put_line(fnd_file.output,'Entered Else Condition');

                 upd_cwk_assignment(
                       p_candidate_id           => r_hire.candidate_id,
                       p_effective_date         => l_start_date,
                       p_assignment_id          => l_assignment_id,
                       p_datetrack_mode         => 'CORRECTION',
                       p_business_group_id      => l_business_group_id,
                       p_supervisor_id          => r_hire.supervisor_id,
                       p_employee_category      => l_employment_category,
                       p_default_code_comb_id   => r_hire.expense_account_id,
                       p_set_of_books_id        => r_hire.set_of_books_id,
                       p_organization_id        => r_hire.organization_id,
                       p_location_id            => r_hire.location_id,
                       p_job_id                 => r_hire.job_id,
                       p_object_version_number  => l_asg_object_version_number);

                DBMS_OUTPUT.PUT_LINE ('Before rate value');
              IF l_business_group_id <> 1631 THEN  --2.6 BRZ TALEO INEGRATION
                create_rate_value (
                        p_business_group_id => l_business_group_id,
                        p_effective_date    => l_start_date,
                        p_assignment_id     => l_assignment_id,
                        p_rate_id           => r_hire.rate_id,
                        p_salary            => r_hire.salary);

                DBMS_OUTPUT.PUT_LINE ('After rate value');
                DBMS_OUTPUT.PUT_LINE ('Before costing');

                create_costing (
                            p_effective_date         => l_start_date,
                            p_assignment_id          => l_assignment_id,
                            p_business_group_id      => l_business_group_id,
                            p_proportion             => 1,
                            p_segment1               => r_hire.gl_location_override, -- Version 2.0
                            p_segment2               => r_hire.client_code
                           );

                DBMS_OUTPUT.PUT_LINE ('After Costing');

                DBMS_OUTPUT.PUT_LINE ('Before Agency Name');
                 create_agency_name (
                        p_person_id         => l_person_id,
                        p_business_group_id => l_business_group_id,
                        p_effective_date    => l_start_date,
                        p_agency_name       => r_hire.agency_name,
                        p_ssn               => r_hire.national_identifier);

                DBMS_OUTPUT.PUT_LINE ('After Agency Name');
                DBMS_OUTPUT.PUT_LINE ('Before Bill');
                -- Bill At Will
                create_bill_at_will(
                     p_person_id => l_person_id,
                     p_employee_number => l_npw_number,
                     p_client_code => r_hire.client_code,
                     p_client_desc => r_hire.client_desc,
                     p_program => r_hire.program,
                     p_program_desc => r_hire.program_desc,
                     p_project => r_hire.project,
                     p_project_desc => r_hire.project_desc,
                     p_project_start => l_start_date,
                     p_project_end => g_oracle_end_date,
                     p_full_name => l_full_name,
                     p_business_group_id => l_business_group_id,
                     p_location_id  => r_hire.location_id,
                     p_emp_type     => 'CWK',
                     p_person_type  => l_person_type);

                DBMS_OUTPUT.PUT_LINE ('After Bill');
                  END IF; --- 2.6 BRZ TALEO INEGRATION
            END IF;

            -- set records completed counter
            l_records_processed := l_records_processed + 1;


           --  update table with record processed, employee number, update date
            update_interface (1,
                             r_hire.ROWID,
                             l_person_id,
                             l_employee_number,
                             l_npw_number
                            );
            COMMIT;

           -- set counter for employees created  / rehired
           IF g_action_type = 'CREATE'
           THEN

            l_records_employee_create := l_records_employee_create + 1;

           ELSIF g_action_type = 'REHIRE'
           THEN

            l_records_rehire := l_records_rehire + 1;

           END IF;

       EXCEPTION
           WHEN skip_record
           THEN
               ROLLBACK;
               log_error;
               update_interface (-1, r_hire.ROWID, NULL, NULL,NULL);
               COMMIT;
               l_records_errored := l_records_errored + 1;
            WHEN OTHERS
            THEN
               ROLLBACK;
               g_error_message      := 'Other Error' || SQLERRM;
               g_label2             := 'Candidate';
               g_secondary_column   := r_hire.candidate_id;
               log_error;

               update_interface (-1, r_hire.ROWID, NULL, NULL,NULL);

               COMMIT;

               l_records_errored    := l_records_errored + 1;
       END;

     END LOOP;

      --COMMIT;
      -- display control totals
      print_line ('');
      print_line ('--------------------TALEO SUMMARY-------------------------');
      print_line (   ' TOTAL RECORDS FOR DATA FILE READ  = '
                  || TO_CHAR (l_records_read)
                 );
      print_line (   ' TOTAL RECORDS FOR IMPORT FULLY PROCESSED  = '
                  || TO_CHAR (l_records_processed)
                 );
      print_line (   ' TOTAL RECORDS FOR IMPORT ERROR  = '
                  || TO_CHAR (l_records_errored)
                 );
      print_line (   ' TOTAL RECORDS FOR REHIRED = '
                  || TO_CHAR (l_records_rehire)
                 );
      print_line ('----------------------------------------------------------');
      -- Report employee numbers created by the interface
      report_new_hire;
      -- Output trailer information
      print_line ('');

      print_line ('');
      print_line (   ' INTERFACE END TIMESTAMP = ' || TO_CHAR (SYSDATE, 'dd-mon-yy hh:mm:ss') );
   END import_new_hire;

END Tt_Taleo_Interface_Pkg;
/
show errors;
/