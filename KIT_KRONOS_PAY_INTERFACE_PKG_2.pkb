create or replace PACKAGE BODY      KIT_KRONOS_PAY_INTERFACE_PKG_2 IS

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
Developer  Date        Description
---------  ----------  --------------------------------------------------
M Dodge    12/20/2007  Replace Business Group ID with Country Code param.
M Dodge    12/27/2007  Added Date_Earned to the BEE Batch Lines.
M Dodge    01/08/2008  Removed Purging of Prior Batches from KSS Interface.
P Elango 12/Jul/2011  R#789662  Exclude US and CA for international business group condistin
                        so it return one row
P Elango  8/23/2018 Handling exception in batch line lever and date format change in specification ,  Added mulitiple Atelka element
MXKEERTHI(ARGANO)  05/05/2023   1.0          R12.2 Upgrade Remediation
-----------------------------------------------------------------------*/

PROCEDURE KIT_KRONOS_PAYROLL_INTERFACE (vCountryCode varchar2, vBatchName varchar2)  IS

   BEGIN

--Get the Business Group ID for the input CountryCode
      SELECT hou.business_group_id
        INTO l_bus_group_id
		   	  --START R12.2 Upgrade Remediation
	  /*
		Commented code by MXKEERTHI-ARGANO, 05/05/2023
      FROM hr.hr_all_organization_units HOU
           , hr.hr_locations_all hl
	   */
	  --code Added  by MXKEERTHI-ARGANO, 05/05/2023
	  FROM apps.hr_all_organization_units HOU
           , apps.hr_locations_all hl
	  --END R12.2.10 Upgrade remediation
		
        
       WHERE hou.ORGANIZATION_ID =
                (CASE WHEN hou.business_group_id !=5054 THEN hou.business_group_id
                      WHEN hou.business_group_id = 5054 AND hl.country NOT IN ('US','CA') THEN    -- R#789662
                       (SELECT TO_NUMBER(SUBSTR(SYS_CONNECT_BY_PATH(pose.organization_id_child,'-')
                                            ,2 ,INSTR(SYS_CONNECT_BY_PATH(pose.organization_id_child,'-')||'-','-',2)
                                                      - 2))
                        FROM per_org_structure_elements pose
                         , hr_all_organization_units org
                         , hr_all_organization_units orc
                         , per_org_structure_versions pvr
                      WHERE pvr.business_group_id = 5054
                       AND TRUNC(SYSDATE) BETWEEN pvr.date_from AND NVL(pvr.date_to, SYSDATE)
                       AND pose.org_structure_version_id = pvr.org_structure_version_id
                       AND org.organization_id = pose.organization_id_parent
                       AND orc.organization_id = pose.organization_id_child
                       AND pose.organization_id_child = hou.organization_id
                      START WITH pose.organization_id_parent = 5054
                     CONNECT BY PRIOR pose.organization_id_child = pose.organization_id_parent) END)
         AND hl.location_id = hou.location_id
         AND hl.country = vCountryCode;

--Delete Processed records before processing new records.
--      DELETE FROM KSS_PAYROLL_ORACLE
--       WHERE BATCH_NAME like trim(substr(vBatchName, 0, 7))
--         AND BATCH_NAME <> vBatchName
--         AND DELETIONINDICATOR='1';


--Loop for the Header Records and process the Batch
      FOR Kronos_Header_Rec IN Kronos_Header_Csr(vBatchName) LOOP
         l_batch_name:=trim(Kronos_Header_Rec.batch_name);
         L_ERROR_RECORD:='create_batch_header';

         --Invoke the Api for Creating the Batch Header Record.
         PAY_BATCH_ELEMENT_ENTRY_API.create_batch_header
         (     p_validate                 => FALSE
             , p_session_date             => sysdate
             , p_batch_name               => trim(Kronos_Header_Rec.batch_name)
             , p_business_group_id        => l_bus_group_id
             , p_batch_status             => 'U'
             , p_action_if_exists         => 'I'
             , p_purge_after_transfer     => 'N'
             , p_reject_if_future_changes => 'Y'
             , p_batch_id                 => l_batch_id
             , p_object_version_number    => l_object_version_number
             , p_batch_reference          => to_char(trunc(sysdate))
             , p_batch_source             => 'BEE Interface pkg2'
             , p_comments                 => null
             , p_date_effective_changes   => null
         );

         -- increment the number of rows processed by the api to keep a count
         l_rows_processed := l_rows_processed + 1;

        --Process the BATCH_HEADER_LINE record
         FOR Kronos_Line_Rec IN Kronos_Line_Csr(l_bus_group_id, vBatchName) LOOP
           --Kronos
            L_ERROR_RECORD:='KRONOS_LINE_CSR';

            --Check the Element type Vacation Earn  and put the effective dates

            l_effective_start_date:=Kronos_Line_Rec.EFFECTIVE_START_DATE;
            l_effective_end_date:=Kronos_Line_Rec.EFFECTIVE_END_DATE;

           --To Generate the Sequence for the Oracle to show up by element name
            IF UPPER(Kronos_Line_Rec.Element_Name)=upper(l_last_element_name) THEN
               l_sequence_no :=l_sequence_no + 1;
            ELSE
               l_last_element_name:=trim(Kronos_Line_Rec.Element_Name);
               l_sequence_no :=1;



                --To Get the Element type ID based on the Element Name
               OPEN csr_element(Kronos_Line_Rec.element_name,Kronos_Line_Rec.effective_date, l_bus_group_id);
               FETCH csr_element into l_element_type_id;
               CLOSE csr_element;

            END IF;



            --To Get the AssignmentID from the Assignment Number
            OPEN csr_assignment(Kronos_Line_Rec.assignment_number,Kronos_Line_Rec.effective_date, l_bus_group_id);
            FETCH csr_assignment into l_assignment_id;
            CLOSE csr_assignment;

            BEGIN
            --Invoke the Api for inserting the data into the Pay Batch Lines
            PAY_BATCH_ELEMENT_ENTRY_API.create_batch_line
            (        p_validate                   => FALSE
                   , p_session_date               =>sysdate
                   , p_batch_id                   =>l_batch_id
                   , p_batch_line_status          =>'U'
                   , p_assignment_id              =>trim(l_assignment_id)
                   , p_assignment_number          =>trim(Kronos_Line_Rec.assignment_number)
                   , p_batch_sequence             => l_sequence_no
                   , p_effective_date             =>Kronos_Line_Rec.effective_date      -- payperiod end date
                   , p_effective_end_date         =>trim(l_effective_end_date)
                   , p_effective_start_date       =>trim(l_effective_start_date)
                   , p_element_name               =>trim(Kronos_Line_Rec.Element_Name)
                   , p_element_type_id            =>trim(l_element_type_id)
                   , p_entry_type                 =>trim(Kronos_Line_Rec.Entry_Type)    --'E'
                   , p_reason                     => trim(Kronos_Line_Rec.Reason)
                   , p_value_1                    =>Kronos_Line_Rec.value_1
                   , p_value_2                    =>Kronos_Line_Rec.value_2
                   , p_value_3                    =>Kronos_Line_Rec.value_3
                   , p_batch_line_id              =>l_batch_line_id
                   , p_object_version_number      =>l_object_version_number
                   , p_date_earned                =>Kronos_Line_Rec.Date_Earned
                   , P_attribute_category         => null
                   , P_attribute1                 => null
                   , P_attribute2                 => null
                   , P_attribute3                 => null
                   , P_attribute4                 => null
                   , P_attribute5                 => null
                   , P_attribute6                 => null
                   , P_attribute7                 => null
                   , P_attribute8                 => null
                   , P_attribute9                 => null
                   , P_attribute10                => null
                   , P_attribute11                => null
                   , P_attribute12                => null
                   , P_attribute13                => null
                   , P_attribute14                => null
                   , P_attribute15                => null
                   , P_attribute16                => null
                   , P_attribute17                => null
                   , P_attribute18                => null
                   , P_attribute19                => null
                   , P_attribute20                => null
                   , P_concatenated_segments      => null
                   , P_cost_allocation_keyflex_id => null
                   , P_segment1                   => null
                   , P_segment2                   => null
                   , P_segment3                   => null
                   , P_segment4                   => null
                   , P_segment5                   => null
                   , P_segment6                   => null
                   , P_segment7                   => null
                   , P_segment8                   => null
                   , P_segment9                   => null
                   , P_segment10                  => null
                   , P_segment11                  => null
                   , P_segment12                  => null
                   , P_segment13                  => null
                   , P_segment14                  => null
                   , P_segment15                  => null
                   , P_segment16                  => null
                   , P_segment17                  => null
                   , P_segment18                  => null
                   , P_segment19                  => null
                   , P_segment20                  => null
                   , P_segment21                  => null
                   , P_segment22                  => null
                   , P_segment23                  => null
                   , P_segment24                  => null
                   , P_segment25                  => null
                   , P_segment26                  => null
                   , P_segment27                  => null
                   , P_segment28                  => null
                   , P_segment29                  => null
                   , P_segment30                  => null
                   , P_value_4                    => null
                   , P_value_5                    => null
                   , P_value_6                    => null
                   , P_value_7                    => null
                   , P_value_8                    => null
                   , P_value_9                    => null
                   , P_value_10                   => null
                   , P_value_11                   => null
                   , P_value_12                   => null
                   , P_value_13                   => null
                   , P_value_14                   => null
                   , P_value_15                   => null
            );
         EXCEPTION
           WHEN OTHERS THEN

             L_ERROR_MESSAGE := 'Error Line level--> '||SQLERRM;
             INSERT INTO KSS_PAYROLL_ERROR
                ( BATCH_NAME
                , BATCH_DATE
                , RECORD_TRACK
                , MESSAGE,ERROR_RECORD )
             VALUES
                ( 'KRONOS_BATCH_LINE_PROCESS'
                , SYSDATE
                , l_batch_name
                , L_ERROR_MESSAGE
                , trim(Kronos_Line_Rec.assignment_number)||' ~ '||Kronos_Line_Rec.Element_Name );


         END;

--
            l_rows_lines_processed :=l_rows_lines_processed + 1;
            COMMIT;
--
         END LOOP;

--Make the records as processed
         UPDATE KSS_PAYROLL_ORACLE
            SET DELETIONINDICATOR='1'
          WHERE UPPER(BATCH_NAME) = Kronos_Header_Rec.Batch_Name;

         COMMIT;
--End the Loop for execution of one batch
      END LOOP;


   EXCEPTION WHEN OTHERS THEN
--Log the Error
      BEGIN
         L_ERROR_MESSAGE := 'Error --> '||SQLERRM;
         INSERT INTO KSS_PAYROLL_ERROR
            ( BATCH_NAME
            , BATCH_DATE
            , RECORD_TRACK
            , MESSAGE,ERROR_RECORD )
         VALUES
            ( 'KRONOS_BATCH_PROCESS'
            , SYSDATE
            , l_batch_name
            , L_ERROR_MESSAGE
            , L_ERROR_RECORD );

         COMMIT;

      END;

--End of Procedure
   END KIT_KRONOS_PAYROLL_INTERFACE;

END KIT_KRONOS_PAY_INTERFACE_PKG_2;
/
show errors;
/