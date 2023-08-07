create or replace package      TELTEC_CUSTOM_WF_UTILITY
as
-- XCELICOR Custom objects
-- Mark Mestetskiy
-- 10-Aug-06
-- 1-Dec-2006 - Added findUserInMgrLevelHierarchy function into spec

Type v_t_type is Table of Varchar2(300) index by Binary_Integer;

Type gradeInfo_Type is Record (minValue number,midValue Number,maxValue Number,gradeId Number);

Type LookupRecord_Type is Record (lookup_code fnd_lookup_values.lookup_code%TYPE,
                             meaning     fnd_lookup_values.meaning%TYPE,
							 description fnd_lookup_values.description%TYPE);

Procedure computeTimeout (p_item_type    in varchar2,
                          p_item_key     in varchar2,
                          p_act_id       in number,
                          funmode     in varchar2,
                          result      out nocopy varchar2  );

Function getLocationCountry(p_location_id Number) Return Varchar2;


Type LookupRecord_tableType is Table of LookupRecord_Type index by Binary_Integer;

Procedure increaseApprovalLevel(p_item_type    in varchar2,
                               p_item_key     in varchar2,
                               p_act_id       in number,
                               funmode     in varchar2,
                               result      out nocopy varchar2  );

Procedure setInitialApprover(p_item_type    in varchar2,
                               p_item_key     in varchar2,
                               p_act_id       in number,
                               funmode     in varchar2,
                               result      out nocopy varchar2  ) ;

Procedure setupApproverRole(p_item_type    in varchar2,
                               p_item_key     in varchar2,
                               p_act_id       in number,
                               funmode     in varchar2,
                               result      out nocopy varchar2  ) ;

Function getPayRuleDescription(p_business_group_id Number,p_location_id Varchar2,p_department Varchar2,p_table Varchar2) Return Varchar2;


Function getuserNameFromUserId(p_user_id Number) Return Varchar2;


Function getTransactionValue(p_transactionid Number) Return Varchar;


Procedure ttec_chg_manager_initialize( p_item_type    in varchar2,
                                    p_item_key     in varchar2,
                                    p_act_id       in number,

                                    funmode     in varchar2,
                                    result      out nocopy varchar2  );


Function findUserInJobHierarchy(p_job_code Varchar2,p_person_id Number)
Return Varchar2;

Procedure findSrHumanCapital(p_item_type    in varchar2,

                               p_item_key     in varchar2,
                               p_act_id       in number,
                               funmode     in varchar2,
                               result      out nocopy varchar2  );



Function getStrings(p_items Varchar2, p_delimiter Varchar2)  Return v_t_type;

Function getSupervisorUser (p_personid in Number) Return Number;

Function getPersonFullName (p_personid in Number) Return Varchar2;

Function getJobName(p_jobId Number) Return Varchar2;

Function getGradeId(p_gradeName Varchar2,p_bid Number) Return number;


Procedure generateSupTransferFYIList(      p_item_type    in varchar2,
                                    p_item_key     in varchar2,
                                    p_act_id       in number,
                                    funmode     in varchar2,
                                    result      out nocopy varchar2);



Procedure generateAdHocRoleHR(      p_item_type    in varchar2,
                                    p_item_key     in varchar2,
                                    p_act_id       in number,
                                    funmode     in varchar2,

                                    result      out nocopy varchar2  );

procedure CreateAdHocUser(      p_item_type    in varchar2,
                                p_item_key     in varchar2,
                                p_act_id       in number,
                                funmode     in varchar2,
                                result      out nocopy varchar2  );

Procedure ttech_next_approver( p_item_type    in varchar2,

                                    p_item_key     in varchar2,
                                    p_act_id       in number,
                                    funmode     in varchar2,

                                    result      out nocopy varchar2  );



Function FindNextPersonOrGroup(p_item_type Varchar2,p_item_key Varchar2) Return Varchar2;

Function getCountry(p_person_id Number) Return Varchar2;

--Function getDepartmentNumber(p_person_id Number) Return hr.pay_cost_allocation_keyflex.segment3%TYPE;		-- Commented code by IXPRAVEEN-ARGANO,13-july-2023
Function getDepartmentNumber(p_person_id Number) Return apps.pay_cost_allocation_keyflex.segment3%TYPE;     --  code Added by IXPRAVEEN-ARGANO,   13-july-2023


Procedure getLookupValues(p_lookupTable IN OUT LookupRecord_TableType,
                          p_lookup_type fnd_lookup_values.LOOKUP_TYPE%TYPE);



Function getLocationGlCode(p_person_id Number) Return Number;

Function ttec_adhoc_hr_local ( p_person_id Number,responsibilityKey Varchar2 ) Return Varchar2;


Function getLocationId(p_person_id Number) Return Varchar2;


Function getSupervisor (p_personid in Number) Return Number;



Function getPersonLocationCode (p_person_id in Number) Return Varchar2;


Function getBusinessGroupId (p_person_id Number) Return Number;

 Procedure buildApproversRole( p_item_type    in varchar2,
                               p_item_key     in varchar2,
                               p_act_id       in number,
                               funmode     in varchar2,
                               result      out nocopy varchar2  );


Procedure buildPayChangeApproversRole( p_item_type    in varchar2,

                               p_item_key     in varchar2,
                               p_act_id       in number,
                               funmode     in varchar2,
                               result      out nocopy varchar2  );

Procedure getPayApproverRulesGrades(p_lookup_records IN LookupRecord_tableType,
                                   p_payGradePercent Number,
                                   p_paySalaryPercent Number,
								   p_results OUT LookupRecord_tableType);

 Procedure generateCurrentOSC( p_item_type    in varchar2,
                                    p_item_key     in varchar2,
                                    p_act_id       in number,

                                    funmode     in varchar2,
                                    result      out nocopy varchar2  );

Function ttec_adhoc_hr_corp ( p_person_id Number,responsibilityKey Varchar2 ) Return Varchar2;

Function FindNextPersonOrGroupPay(p_item_type Varchar2,p_item_key Varchar2) Return Varchar2;



Function getJobCodeForPayChanges(p_ruleString Varchar2) Return Varchar2;

Function getPersonIdForPayChanges(p_ruleString Varchar2) Return Varchar2;


Function getManagerLevelForPayChanges(p_ruleString Varchar2) Return Varchar2;

Function findUserFromPersonId(p_person_id Number) Return Varchar2;

Function findUserName(p_user_id Number) Return Varchar2;

Function getSupervisorPersonid (p_personid in Number) Return Number;

Function getOriginalTextTransValue(p_item_key number,p_name Varchar2) Return Varchar2;

Function getOriginalNumTransValue(p_item_key number,p_name Varchar2) Return Number;


Function getTextTransactionValue(p_item_key number,p_name Varchar2) Return Varchar2;

Function getNumTransactionValueFromItem(p_item_key Varchar2,p_name Varchar2) Return Number;

Function getDateTransValue(p_item_key Varchar2,p_name Varchar2) Return Date;

Function getOriginalDateTransValue(p_item_key Varchar2,p_name Varchar2) Return Date;


Procedure customGlobals(p_item_type    in varchar2,
                               p_item_key     in varchar2,
                               p_act_id       in number,
                               funmode     in varchar2,
                               result      out nocopy varchar2  );


Function findUserInLocation(p_job_code Varchar2,p_person_id Number)
Return Varchar2;

Function getGradePercentChange(p_OgradeId Number,p_newGradeId Number,p_effectiveDate Date) Return  Number;

Procedure isSalaryChanged(p_item_type    in varchar2,
                                    p_item_key     in varchar2,
                                    p_act_id       in number,
                                    funmode     in varchar2,
                                    result      out nocopy varchar2 );


Function findOCInJobHierarchy(p_person_id Number) Return Varchar2;

Procedure isAgent(      p_item_type    in varchar2,
                                    p_item_key     in varchar2,
                                    p_act_id       in number,
                                    funmode     in varchar2,
                                    result      out nocopy varchar2  );

Procedure isAgentJobChanged(      p_item_type    in varchar2,
                                    p_item_key     in varchar2,
                                    p_act_id       in number,
                                    funmode     in varchar2,
                                    result      out nocopy varchar2  );


Procedure setupPayStartDate(      p_item_type    in varchar2,
                                    p_item_key     in varchar2,
                                    p_act_id       in number,
                                    funmode     in varchar2,
                                    result      out nocopy varchar2  );

Procedure setupHCMRole(      p_item_type    in varchar2,
                                    p_item_key     in varchar2,
                                    p_act_id       in number,
                                    funmode     in varchar2,
                                    result      out nocopy varchar2  );

Function getOSCEmail(p_person_id Number,p_effective_date Date) Return Varchar2;

Procedure setupOSCUser(      p_item_type    in varchar2,
                                    p_item_key     in varchar2,
                                    p_act_id       in number,
                                    funmode     in varchar2,
                                    result      out nocopy varchar2  );


Procedure setupCorpTermUser(      p_item_type    in varchar2,
                                    p_item_key     in varchar2,
                                    p_act_id       in number,
                                    funmode     in varchar2,
                                    result      out nocopy varchar2  );


Procedure setupReceivingSupUser(      p_item_type    in varchar2,
                                    p_item_key     in varchar2,
                                    p_act_id       in number,
                                    funmode     in varchar2,
                                    result      out nocopy varchar2  );

Function ttec_adhoc_hr_local_unames ( p_person_id Number,responsibilityKey Varchar2 ) Return Varchar2;


Procedure setupReceivingHCMRole(      p_item_type    in varchar2,
                                    p_item_key     in varchar2,
                                    p_act_id       in number,
                                    funmode     in varchar2,
                                    result      out nocopy varchar2  );

Procedure setupOldHCMRole(      p_item_type    in varchar2,
                                    p_item_key     in varchar2,
                                    p_act_id       in number,
                                    funmode     in varchar2,
                                    result      out nocopy varchar2  );


Procedure setupOldOscRole(      p_item_type    in varchar2,
                                    p_item_key     in varchar2,
                                    p_act_id       in number,
                                    funmode     in varchar2,
                                    result      out nocopy varchar2  );

Procedure setupNewOscRole(      p_item_type    in varchar2,
                                    p_item_key     in varchar2,
                                    p_act_id       in number,
                                    funmode     in varchar2,
                                    result      out nocopy varchar2  );


Procedure setupNewSupUserName(      p_item_type    in varchar2,
                                    p_item_key     in varchar2,
                                    p_act_id       in number,
                                    funmode     in varchar2,
                                    result      out nocopy varchar2  );

Procedure setupOldSupUserName(      p_item_type    in varchar2,
                                    p_item_key     in varchar2,
                                    p_act_id       in number,
                                    funmode     in varchar2,
                                    result      out nocopy varchar2  );

Procedure isLocationChanged(      p_item_type    in varchar2,
                                    p_item_key     in varchar2,
                                    p_act_id       in number,
                                    funmode     in varchar2,
                                    result      out nocopy varchar2  );


Procedure setupReceivingHCMRoleLocation( p_item_type    in varchar2,
                                         p_item_key     in varchar2,
                                         p_act_id       in number,
                                         funmode        in varchar2,
                                         result         out nocopy varchar2  );

Procedure setupOldHCMRoleLocation(      p_item_type    in varchar2,
                                    p_item_key     in varchar2,
                                    p_act_id       in number,
                                    funmode     in varchar2,
                                    result      out nocopy varchar2  );

Procedure setupOldOscRoleAssignment(      p_item_type    in varchar2,
                                    p_item_key     in varchar2,
                                    p_act_id       in number,
                                    funmode     in varchar2,
                                    result      out nocopy varchar2  );

Procedure setupNewOscRoleAssignment(      p_item_type    in varchar2,
                                    p_item_key     in varchar2,
                                    p_act_id       in number,
                                    funmode     in varchar2,
                                    result      out nocopy varchar2  );

Function getOSCEmailLocation(p_location_id Number,p_effective_date Date) Return Varchar2;

Procedure setupOldOscRoleLocation(      p_item_type    in varchar2,
                                    p_item_key     in varchar2,
                                    p_act_id       in number,
                                    funmode     in varchar2,
                                    result      out nocopy varchar2  );

Procedure setupNewOscRoleLocation(      p_item_type    in varchar2,
                                    p_item_key     in varchar2,
                                    p_act_id       in number,
                                    funmode     in varchar2,
                                    result      out nocopy varchar2  );


Procedure isDemotedToAgentJob(      p_item_type    in varchar2,
                                    p_item_key     in varchar2,
                                    p_act_id       in number,
                                    funmode     in varchar2,
                                    result      out nocopy varchar2  );

Procedure isPromotedFromAgentJob(      p_item_type    in varchar2,
                                    p_item_key     in varchar2,
                                    p_act_id       in number,
                                    funmode     in varchar2,
                                    result      out nocopy varchar2  );


Function ttec_adhoc_hr_local_unames_l ( p_location_id Number,p_organization_id Number,responsibilityKey Varchar2 ) Return Varchar2;

Procedure isPayBasisHasToBeChanged(
                                    p_item_type    in varchar2,
                                    p_item_key     in varchar2,
                                    p_act_id       in number,
                                    funmode     in varchar2,
                                    result      out nocopy varchar2  );



Function findUserInMgrLevelHierarchy(p_job_code Varchar2,p_person_id Number)
return Varchar2;


FUNCTION getLocationName(p_location_id NUMBER) RETURN Varchar2;

Function getPersonIdByUserName(p_user_name Varchar2) Return Number;

Procedure setupActualApprover(      p_item_type    IN VARCHAR2,
                                    p_item_key     IN VARCHAR2,
                                    p_act_id       IN NUMBER,
                                    funmode     IN VARCHAR2,
                                    result      OUT NOCOPY VARCHAR2  );


PROCEDURE myDebug(msg VARCHAR2);


Function getHcmRoleDescription(p_item_key Varchar2) Return Varchar2;

FUNCTION getLocationNamePid(p_person_id NUMBER) RETURN Varchar2;


G_isLocationChanged Boolean :=FALSE;
G_newLocationId    Varchar2(20);

G_wf_role_description  Varchar2(100):=null;
G_locationName         Varchar2(100):=null;

G_hcm_role_description  Varchar2(100):=null;




end;
/
show errors;
/