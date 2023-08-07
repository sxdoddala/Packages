/************************************************************************************
        Program Name: ESP_VALUE_SETS_PKG

       Modification Log
       Name                  Version #    Date            Description
       -----                 --------     -----           -------------
    IXPRAVEEN(ARGANO)            1.0     15-May-2023     R12.2 Upgrade Remediation
    ****************************************************************************************/
create or replace Package Body      ESP_VALUE_SETS_PKG Is

Procedure ESP_VALUE_SETS_LOAD(errbuf varchar2, retcode number) IS
Cursor Val is
Select
VALUE_SET_NAME      ,
VALUE               ,
TRANSLATED_VALUE    ,
DESCRIPTION         ,
ENABLED_FLAG        ,
--(select to_date('01-jan-1951','dd-mon-yyyy') from dual)
START_DATE_ACTIVE   ,
UPLOAD_FLAG         ,
PROCESSED_FLAG
From
--cust.ttec_value_sets				-- Commented code by IXPRAVEEN-ARGANO,15-May-2023
apps.ttec_value_sets                --  code Added by IXPRAVEEN-ARGANO,   15-May-2023
Where value_set_name like '%TELETECH_ESP_GEO_PLACE_VS%'
And Not Exists
(Select 'x'
From
--START R12.2 Upgrade Remediation
/*applsys.fnd_flex_values v,			-- Commented code by IXPRAVEEN-ARGANO,15-May-2023
applsys.fnd_flex_value_sets s*/
apps.fnd_flex_values v,					--  code Added by IXPRAVEEN-ARGANO,   15-May-2023	
apps.fnd_flex_value_sets s
--END R12.2.12 Upgrade remediation
Where
v.flex_value_set_id = s.flex_value_set_id
And v.enabled_flag='Y'
and s.flex_value_set_name=value_set_name
and v.flex_value=value)
and PROCESSED_FLAG is null
--and rownum<=1000
FOR UPDATE OF PROCESSED_FLAG;


val_seq number := 0;
vValueSetId number :=null;
Begin --Main--
For ValRec In Val Loop
    Begin
    val_seq := 0;
Select fnd_flex_values_s.nextval into val_seq from dual;
--dbms_output.put_line(' VAL -'||val_rec.deg_val);
Select Distinct flex_value_set_id Into vValueSetId
From
--applsys.fnd_flex_value_sets st				-- Commented code by IXPRAVEEN-ARGANO,15-May-2023
apps.fnd_flex_value_sets st						--  code Added by IXPRAVEEN-ARGANO,   15-May-2023
Where flex_value_set_name =ValRec.value_set_name;

Insert Into fnd_flex_values
(
flex_value_set_id,
flex_value_id,
flex_value,
last_update_date,
last_updated_by,
creation_date,
created_by,
last_update_login,
enabled_flag,
summary_flag,
start_date_active
)
Values
(
vValueSetId,
val_seq,
ValRec.Value,
sysdate,-1,sysdate,-1,-1,'Y','N',ValRec.start_date_active);

Insert Into fnd_flex_values_tl
(flex_value_id,
 language, -- this would be say for example: 'E','ESA' ,'KO','PTB','US'--
 last_update_date,
 last_updated_by,
 creation_date,
 created_by,
 last_update_login,
 description,
 source_lang,
 flex_value_meaning )
 Values
 (val_seq,'US',sysdate,-1,sysdate,-1,-1,ValRec.description,'US',ValRec.translated_value);

Insert Into fnd_flex_values_tl
(flex_value_id,
 language, -- this would be say for example: 'E','ESA' ,'KO','PTB','US'--
 last_update_date,
 last_updated_by,
 creation_date,
 created_by,
 last_update_login,
 description,
 source_lang,
 flex_value_meaning )
 Values
 (val_seq,'E',sysdate,-1,sysdate,-1,-1,ValRec.description,'US',ValRec.translated_value);

Insert Into fnd_flex_values_tl
(flex_value_id,
 language, -- this would be say for example: 'E','ESA' ,'KO','PTB','US'--
 last_update_date,
 last_updated_by,
 creation_date,
 created_by,
 last_update_login,
 description,
 source_lang,
 flex_value_meaning )
 Values
 (val_seq,'ESA',sysdate,-1,sysdate,-1,-1,ValRec.description,'US',ValRec.translated_value);

Insert Into fnd_flex_values_tl
(flex_value_id,
 language, -- this would be say for example: 'E','ESA' ,'KO','PTB','US'--
 last_update_date,
 last_updated_by,
 creation_date,
 created_by,
 last_update_login,
 description,
 source_lang,
 flex_value_meaning )
 Values
 (val_seq,'KO',sysdate,-1,sysdate,-1,-1,ValRec.description,'US',ValRec.translated_value);

Insert Into fnd_flex_values_tl
(flex_value_id,
 language, -- this would be say for example: 'E','ESA' ,'KO','PTB','US'--
 last_update_date,
 last_updated_by,
 creation_date,
 created_by,
 last_update_login,
 description,
 source_lang,
 flex_value_meaning )
 Values
 (val_seq,'PTB',sysdate,-1,sysdate,-1,-1,ValRec.description,'US',ValRec.translated_value);

	--Update cust.ttec_value_sets				-- Commented code by IXPRAVEEN-ARGANO,15-May-2023
	Update apps.ttec_value_sets					--  code Added by IXPRAVEEN-ARGANO,   15-May-2023
	set PROCESSED_FLAG='Processed'||val_seq
	WHERE CURRENT OF Val;
    End;

End Loop;

Exception

When others then

--Update cust.ttec_value_sets			-- Commented code by IXPRAVEEN-ARGANO,15-May-2023
Update cust.ttec_value_sets				--  code Added by IXPRAVEEN-ARGANO,   15-May-2023			
	set PROCESSED_FLAG='Err'||val_seq
	WHERE CURRENT OF Val;

Commit;
End ESP_VALUE_SETS_LOAD; --Main--

End ESP_VALUE_SETS_PKG;
/
show errors;
/