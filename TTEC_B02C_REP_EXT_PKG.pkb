create or replace package body      TTEC_B02C_REP_EXT_PKG as
/*
   REM Description:  Package is created for B02C Report, TTEC_B02C_PRC will insert data into Gloabl Temporary Table.
   REM				 Package called from TTEC_PAREVSUMM.rdf Before Report trigger
   REM
   REM ===========================================================================SOFT==========================================
   REM Task       History                 Performed by             REFERENCE                      VENDOR
   REM Created    26-Nov-2017             Hema C                                          Initial Creation
   REM Modified
    Modification Log
       Name                  Version #    Date            Description
       -----                 --------     -----           -------------
    IXPRAVEEN(ARGANO)            1.0     10-May-2023     R12.2 Upgrade Remediation
   REM =====================================================================================================================
*/
Procedure TTEC_B02C_PRC(  p_month in varchar2
						 ,p_oper_unit in number
						 ,p_opp_owner in number
						 ,p_project_manager in number
						 ,p_project_number_frm in number
						 ,p_project_number_to in number
						 ,p_proj_oper_manager in number
						 ,p_proj_partner in number
						 ,p_template in varchar2
                                ) is

BEGIN

--INSERT INTO CUST.TTEC_B02C_REPGT					-- Commented code by IXPRAVEEN-ARGANO,10-May-2023
INSERT INTO apps.TTEC_B02C_REPGT                    --  code Added by IXPRAVEEN-ARGANO,   10-May-2023
(select distinct PPA.SEGMENT1 PROJECT_NUMBER
, PPA.name PROJECT_NAME
, POU.name
, PPA_TEMPLATE.SEGMENT1 TEMPLATE_NAME
, (select
      LISTAGG(FULL_NAME, '; ') WITHIN GROUP (ORDER BY FULL_NAME)
      from
       PA_PROJECT_PLAYERS_V
      where 1=1
      and role(+) = 'Project Partner/Director'
      and  sysdate between START_DATE_ACTIVE(+) and NVL(END_DATE_ACTIVE(+), sysdate+1)
            and PROJECT_ID = PPART.PROJECT_ID) PARTNER
, (select
      LISTAGG(FULL_NAME, '; ') WITHIN GROUP (ORDER BY FULL_NAME)
      from
       PA_PROJECT_PLAYERS_V
      where 1=1
      and role(+) ='Project Manager'
      and sysdate between START_DATE_ACTIVE(+) and NVL(END_DATE_ACTIVE(+), sysdate+1)
            and PROJECT_ID = PPPVM.PROJECT_ID)  PROJECT_MANAGER
, (select
      LISTAGG(FULL_NAME, '; ') WITHIN GROUP (ORDER BY FULL_NAME)
      from
       PA_PROJECT_PLAYERS_V
      where 1=1
      and role(+) = 'Project Operations Manager'
      and  sysdate between START_DATE_ACTIVE(+) and NVL(END_DATE_ACTIVE(+), sysdate+1)
            and PROJECT_ID = PPPOM.PROJECT_ID) POM
,  (select
      LISTAGG(FULL_NAME, '; ') WITHIN GROUP (ORDER BY FULL_NAME)
      from
       PA_PROJECT_PLAYERS_V
      where 1=1
      and role(+) = 'Opportunity Owner'
      and  sysdate between START_DATE_ACTIVE(+) and NVL(END_DATE_ACTIVE(+), sysdate+1)
            and PROJECT_ID = PPOOW.PROJECT_ID) OPP_OWNER
, PPA.PROJECT_ID
, PT.TASK_NUMBER
, PT.TASK_ID
, PE.EVENT_ID TRANSACTION_ID
, PE.DESCRIPTION
, PE.BILL_AMOUNT, PE.BILL_TRANS_REV_AMOUNT REVENUE_AMOUNT, PE.completioN_date
, T.PER1 PERIOD1
, PE.REVENUE_DISTRIBUTED_FLAG
, PE.PROJECT_CURRENCY_CODE
, PE.ATTRIBUTE1
,(select
DECODE(PE.BILL_TRANS_CURRENCY_CODE, GL.CURRENCY_CODE, PE.BILL_TRANS_REV_AMOUNT,
         DECODE(PE.PROJECT_RATE_TYPE , 'User', PE.projfunc_revenue_Amount,
                  DECODE(PE.REVENUE_DISTRIBUTED_FLAG , 'Y', (select PE.BILL_TRANS_REV_AMOUNT*GLD.CONVERSION_RATE from GL_DAILY_RATES GLD where
                                                              GLD.CONVERSION_TYPE = PE.PROJECT_RATE_TYPE
                                                              and GLD.FROM_CURRENCY = PE.BILL_TRANS_CURRENCY_CODE
                                                              and GLD.TO_CURRENCY = GL.CURRENCY_CODE
                                                              and GLD.CONVERSION_DATE  = PE.PROJECT_REV_RATE_DATE),
                                                        'N',
                             DECODE( (select PE.BILL_TRANS_REV_AMOUNT*GLD1.CONVERSION_RATE from GL_DAILY_RATES GLD1 where
                                        GLD1.CONVERSION_TYPE = PE.PROJECT_RATE_TYPE
                                        and GLD1.FROM_CURRENCY = PE.BILL_TRANS_CURRENCY_CODE
                                        and GLD1.TO_CURRENCY = GL.CURRENCY_CODE
                                        and gld1.CONVERSION_DATE  = PE.COMPLETION_DATE), null,
                                      (select PE.BILL_TRANS_REV_AMOUNT*GLD2.CONVERSION_RATE from GL_DAILY_RATES GLD2 where
                                         GLD2.CONVERSION_TYPE = GL.PERIOD_END_RATE_TYPE
                                         and GLD2.FROM_CURRENCY = PE.BILL_TRANS_CURRENCY_CODE
                                         and GLD2.TO_CURRENCY = GL.CURRENCY_CODE
                                         and GLD2.CONVERSION_DATE  = (select max(GLD2_1.CONVERSION_DATE) from GL_DAILY_RATES GLD2_1
                                                                        where
                                                                        GLD2_1.CONVERSION_TYPE = GL.PERIOD_END_RATE_TYPE
                                                                        and GLD2_1.FROM_CURRENCY = PE.BILL_TRANS_CURRENCY_CODE
                                                                        and GLD2_1.TO_CURRENCY = GL.CURRENCY_CODE
                                                                      )
                                         ),
                                      (select PE.BILL_TRANS_REV_AMOUNT*GLD3.CONVERSION_RATE from GL_DAILY_RATES GLD3 where
                                           GLD3.CONVERSION_TYPE = PE.PROJECT_RATE_TYPE
                                           and GLD3.FROM_CURRENCY = PE.BILL_TRANS_CURRENCY_CODE
                                           and GLD3.TO_CURRENCY = GL.CURRENCY_CODE
                                           and gld3.CONVERSION_DATE  = PE.completion_date) ) ) ))
from DUAL where PE.completioN_date between (select distinct START_DATE from   PA_PERIODS_ALL where PERIOD_NAME =T.PER1) and (select distinct END_DATE from   PA_PERIODS_ALL where PERIOD_NAME =T.PER1))
PER1
,
(select
DECODE(PE.BILL_TRANS_CURRENCY_CODE, GL.CURRENCY_CODE, PE.BILL_TRANS_REV_AMOUNT,
         DECODE(PE.PROJECT_RATE_TYPE , 'User', PE.projfunc_revenue_Amount,
                  DECODE(PE.REVENUE_DISTRIBUTED_FLAG , 'Y', (select PE.BILL_TRANS_REV_AMOUNT*GLD.CONVERSION_RATE from GL_DAILY_RATES GLD where
                                                              GLD.CONVERSION_TYPE = PE.PROJECT_RATE_TYPE
                                                              and GLD.FROM_CURRENCY = PE.BILL_TRANS_CURRENCY_CODE
                                                              and GLD.TO_CURRENCY = GL.CURRENCY_CODE
                                                              and GLD.CONVERSION_DATE  = PE.PROJECT_REV_RATE_DATE),
                                                        'N',
                             DECODE( (select PE.BILL_TRANS_REV_AMOUNT*GLD1.CONVERSION_RATE from GL_DAILY_RATES GLD1 where
                                        GLD1.CONVERSION_TYPE = PE.PROJECT_RATE_TYPE
                                        and GLD1.FROM_CURRENCY = PE.BILL_TRANS_CURRENCY_CODE
                                        and GLD1.TO_CURRENCY = GL.CURRENCY_CODE
                                        and gld1.CONVERSION_DATE  = PE.COMPLETION_DATE), null,
                                      (select PE.BILL_TRANS_REV_AMOUNT*GLD2.CONVERSION_RATE from GL_DAILY_RATES GLD2 where
                                         GLD2.CONVERSION_TYPE = GL.PERIOD_END_RATE_TYPE
                                         and GLD2.FROM_CURRENCY = PE.BILL_TRANS_CURRENCY_CODE
                                         and GLD2.TO_CURRENCY = GL.CURRENCY_CODE
                                         and GLD2.CONVERSION_DATE  = (select max(GLD2_1.CONVERSION_DATE) from GL_DAILY_RATES GLD2_1
                                                                        where
                                                                        GLD2_1.CONVERSION_TYPE = GL.PERIOD_END_RATE_TYPE
                                                                        and GLD2_1.FROM_CURRENCY = PE.BILL_TRANS_CURRENCY_CODE
                                                                        and GLD2_1.TO_CURRENCY = GL.CURRENCY_CODE
                                                                      )
                                         ),
                                      (select PE.BILL_TRANS_REV_AMOUNT*GLD3.CONVERSION_RATE from GL_DAILY_RATES GLD3 where
                                           GLD3.CONVERSION_TYPE = PE.PROJECT_RATE_TYPE
                                           and GLD3.FROM_CURRENCY = PE.BILL_TRANS_CURRENCY_CODE
                                           and GLD3.TO_CURRENCY = GL.CURRENCY_CODE
                                           and gld3.CONVERSION_DATE  = PE.completion_date) ) ) ))
from DUAL where PE.completioN_date between (select distinct START_DATE from   PA_PERIODS_ALL where PERIOD_NAME =T.PER2) and (select distinct END_DATE from   PA_PERIODS_ALL where PERIOD_NAME =T.PER2))
PER2
,
(select
DECODE(PE.BILL_TRANS_CURRENCY_CODE, GL.CURRENCY_CODE, PE.BILL_TRANS_REV_AMOUNT,
         DECODE(PE.PROJECT_RATE_TYPE , 'User', PE.projfunc_revenue_Amount,
                  DECODE(PE.REVENUE_DISTRIBUTED_FLAG , 'Y', (select PE.BILL_TRANS_REV_AMOUNT*GLD.CONVERSION_RATE from GL_DAILY_RATES GLD where
                                                              GLD.CONVERSION_TYPE = PE.PROJECT_RATE_TYPE
                                                              and GLD.FROM_CURRENCY = PE.BILL_TRANS_CURRENCY_CODE
                                                              and GLD.TO_CURRENCY = GL.CURRENCY_CODE
                                                              and GLD.CONVERSION_DATE  = PE.PROJECT_REV_RATE_DATE),
                                                        'N',
                             DECODE( (select PE.BILL_TRANS_REV_AMOUNT*GLD1.CONVERSION_RATE from GL_DAILY_RATES GLD1 where
                                        GLD1.CONVERSION_TYPE = PE.PROJECT_RATE_TYPE
                                        and GLD1.FROM_CURRENCY = PE.BILL_TRANS_CURRENCY_CODE
                                        and GLD1.TO_CURRENCY = GL.CURRENCY_CODE
                                        and gld1.CONVERSION_DATE  = PE.COMPLETION_DATE), null,
                                      (select PE.BILL_TRANS_REV_AMOUNT*GLD2.CONVERSION_RATE from GL_DAILY_RATES GLD2 where
                                         GLD2.CONVERSION_TYPE = GL.PERIOD_END_RATE_TYPE
                                         and GLD2.FROM_CURRENCY = PE.BILL_TRANS_CURRENCY_CODE
                                         and GLD2.TO_CURRENCY = GL.CURRENCY_CODE
                                         and GLD2.CONVERSION_DATE  = (select max(GLD2_1.CONVERSION_DATE) from GL_DAILY_RATES GLD2_1
                                                                        where
                                                                        GLD2_1.CONVERSION_TYPE = GL.PERIOD_END_RATE_TYPE
                                                                        and GLD2_1.FROM_CURRENCY = PE.BILL_TRANS_CURRENCY_CODE
                                                                        and GLD2_1.TO_CURRENCY = GL.CURRENCY_CODE
                                                                      )
                                         ),
                                      (select PE.BILL_TRANS_REV_AMOUNT*GLD3.CONVERSION_RATE from GL_DAILY_RATES GLD3 where
                                           GLD3.CONVERSION_TYPE = PE.PROJECT_RATE_TYPE
                                           and GLD3.FROM_CURRENCY = PE.BILL_TRANS_CURRENCY_CODE
                                           and GLD3.TO_CURRENCY = GL.CURRENCY_CODE
                                           and gld3.CONVERSION_DATE  = PE.completion_date) ) ) ))
from DUAL where PE.completioN_date between (select distinct START_DATE from   PA_PERIODS_ALL where PERIOD_NAME =T.PER3) and (select distinct END_DATE from   PA_PERIODS_ALL where PERIOD_NAME =T.PER3))
PER3
,(select
DECODE(PE.BILL_TRANS_CURRENCY_CODE, GL.CURRENCY_CODE, PE.BILL_TRANS_REV_AMOUNT,
         DECODE(PE.PROJECT_RATE_TYPE , 'User', PE.projfunc_revenue_Amount,
                  DECODE(PE.REVENUE_DISTRIBUTED_FLAG , 'Y', (select PE.BILL_TRANS_REV_AMOUNT*GLD.CONVERSION_RATE from GL_DAILY_RATES GLD where
                                                              GLD.CONVERSION_TYPE = PE.PROJECT_RATE_TYPE
                                                              and GLD.FROM_CURRENCY = PE.BILL_TRANS_CURRENCY_CODE
                                                              and GLD.TO_CURRENCY = GL.CURRENCY_CODE
                                                              and GLD.CONVERSION_DATE  = PE.PROJECT_REV_RATE_DATE),
                                                        'N',
                             DECODE( (select PE.BILL_TRANS_REV_AMOUNT*GLD1.CONVERSION_RATE from GL_DAILY_RATES GLD1 where
                                        GLD1.CONVERSION_TYPE = PE.PROJECT_RATE_TYPE
                                        and GLD1.FROM_CURRENCY = PE.BILL_TRANS_CURRENCY_CODE
                                        and GLD1.TO_CURRENCY = GL.CURRENCY_CODE
                                        and gld1.CONVERSION_DATE  = PE.COMPLETION_DATE), null,
                                      (select PE.BILL_TRANS_REV_AMOUNT*GLD2.CONVERSION_RATE from GL_DAILY_RATES GLD2 where
                                         GLD2.CONVERSION_TYPE = GL.PERIOD_END_RATE_TYPE
                                         and GLD2.FROM_CURRENCY = PE.BILL_TRANS_CURRENCY_CODE
                                         and GLD2.TO_CURRENCY = GL.CURRENCY_CODE
                                         and GLD2.CONVERSION_DATE  = (select max(GLD2_1.CONVERSION_DATE) from GL_DAILY_RATES GLD2_1
                                                                        where
                                                                        GLD2_1.CONVERSION_TYPE = GL.PERIOD_END_RATE_TYPE
                                                                        and GLD2_1.FROM_CURRENCY = PE.BILL_TRANS_CURRENCY_CODE
                                                                        and GLD2_1.TO_CURRENCY = GL.CURRENCY_CODE
                                                                      )
                                         ),
                                      (select PE.BILL_TRANS_REV_AMOUNT*GLD3.CONVERSION_RATE from GL_DAILY_RATES GLD3 where
                                           GLD3.CONVERSION_TYPE = PE.PROJECT_RATE_TYPE
                                           and GLD3.FROM_CURRENCY = PE.BILL_TRANS_CURRENCY_CODE
                                           and GLD3.TO_CURRENCY = GL.CURRENCY_CODE
                                           and gld3.CONVERSION_DATE  = PE.completion_date) ) ) ))
from DUAL where PE.completioN_date between (select distinct START_DATE from   PA_PERIODS_ALL where PERIOD_NAME =T.PER4) and (select distinct END_DATE from   PA_PERIODS_ALL where PERIOD_NAME =T.PER4))
PER4
,(select
DECODE(PE.BILL_TRANS_CURRENCY_CODE, GL.CURRENCY_CODE, PE.BILL_TRANS_REV_AMOUNT,
         DECODE(PE.PROJECT_RATE_TYPE , 'User', PE.projfunc_revenue_Amount,
                  DECODE(PE.REVENUE_DISTRIBUTED_FLAG , 'Y', (select PE.BILL_TRANS_REV_AMOUNT*GLD.CONVERSION_RATE from GL_DAILY_RATES GLD where
                                                              GLD.CONVERSION_TYPE = PE.PROJECT_RATE_TYPE
                                                              and GLD.FROM_CURRENCY = PE.BILL_TRANS_CURRENCY_CODE
                                                              and GLD.TO_CURRENCY = GL.CURRENCY_CODE
                                                              and GLD.CONVERSION_DATE  = PE.PROJECT_REV_RATE_DATE),
                                                        'N',
                             DECODE( (select PE.BILL_TRANS_REV_AMOUNT*GLD1.CONVERSION_RATE from GL_DAILY_RATES GLD1 where
                                        GLD1.CONVERSION_TYPE = PE.PROJECT_RATE_TYPE
                                        and GLD1.FROM_CURRENCY = PE.BILL_TRANS_CURRENCY_CODE
                                        and GLD1.TO_CURRENCY = GL.CURRENCY_CODE
                                        and gld1.CONVERSION_DATE  = PE.COMPLETION_DATE), null,
                                      (select PE.BILL_TRANS_REV_AMOUNT*GLD2.CONVERSION_RATE from GL_DAILY_RATES GLD2 where
                                         GLD2.CONVERSION_TYPE = GL.PERIOD_END_RATE_TYPE
                                         and GLD2.FROM_CURRENCY = PE.BILL_TRANS_CURRENCY_CODE
                                         and GLD2.TO_CURRENCY = GL.CURRENCY_CODE
                                         and GLD2.CONVERSION_DATE  = (select max(GLD2_1.CONVERSION_DATE) from GL_DAILY_RATES GLD2_1
                                                                        where
                                                                        GLD2_1.CONVERSION_TYPE = GL.PERIOD_END_RATE_TYPE
                                                                        and GLD2_1.FROM_CURRENCY = PE.BILL_TRANS_CURRENCY_CODE
                                                                        and GLD2_1.TO_CURRENCY = GL.CURRENCY_CODE
                                                                      )
                                         ),
                                      (select PE.BILL_TRANS_REV_AMOUNT*GLD3.CONVERSION_RATE from GL_DAILY_RATES GLD3 where
                                           GLD3.CONVERSION_TYPE = PE.PROJECT_RATE_TYPE
                                           and GLD3.FROM_CURRENCY = PE.BILL_TRANS_CURRENCY_CODE
                                           and GLD3.TO_CURRENCY = GL.CURRENCY_CODE
                                           and gld3.CONVERSION_DATE  = PE.completion_date) ) ) ))
from DUAL where PE.completioN_date between (select distinct START_DATE from   PA_PERIODS_ALL where PERIOD_NAME =T.PER5) and (select distinct END_DATE from   PA_PERIODS_ALL where PERIOD_NAME =T.PER5))
PER5
,(select
DECODE(PE.BILL_TRANS_CURRENCY_CODE, GL.CURRENCY_CODE, PE.BILL_TRANS_REV_AMOUNT,
         DECODE(PE.PROJECT_RATE_TYPE , 'User', PE.projfunc_revenue_Amount,
                  DECODE(PE.REVENUE_DISTRIBUTED_FLAG , 'Y', (select PE.BILL_TRANS_REV_AMOUNT*GLD.CONVERSION_RATE from GL_DAILY_RATES GLD where
                                                              GLD.CONVERSION_TYPE = PE.PROJECT_RATE_TYPE
                                                              and GLD.FROM_CURRENCY = PE.BILL_TRANS_CURRENCY_CODE
                                                              and GLD.TO_CURRENCY = GL.CURRENCY_CODE
                                                              and GLD.CONVERSION_DATE  = PE.PROJECT_REV_RATE_DATE),
                                                        'N',
                             DECODE( (select PE.BILL_TRANS_REV_AMOUNT*GLD1.CONVERSION_RATE from GL_DAILY_RATES GLD1 where
                                        GLD1.CONVERSION_TYPE = PE.PROJECT_RATE_TYPE
                                        and GLD1.FROM_CURRENCY = PE.BILL_TRANS_CURRENCY_CODE
                                        and GLD1.TO_CURRENCY = GL.CURRENCY_CODE
                                        and gld1.CONVERSION_DATE  = PE.COMPLETION_DATE), null,
                                      (select PE.BILL_TRANS_REV_AMOUNT*GLD2.CONVERSION_RATE from GL_DAILY_RATES GLD2 where
                                         GLD2.CONVERSION_TYPE = GL.PERIOD_END_RATE_TYPE
                                         and GLD2.FROM_CURRENCY = PE.BILL_TRANS_CURRENCY_CODE
                                         and GLD2.TO_CURRENCY = GL.CURRENCY_CODE
                                         and GLD2.CONVERSION_DATE  = (select max(GLD2_1.CONVERSION_DATE) from GL_DAILY_RATES GLD2_1
                                                                        where
                                                                        GLD2_1.CONVERSION_TYPE = GL.PERIOD_END_RATE_TYPE
                                                                        and GLD2_1.FROM_CURRENCY = PE.BILL_TRANS_CURRENCY_CODE
                                                                        and GLD2_1.TO_CURRENCY = GL.CURRENCY_CODE
                                                                      )
                                         ),
                                      (select PE.BILL_TRANS_REV_AMOUNT*GLD3.CONVERSION_RATE from GL_DAILY_RATES GLD3 where
                                           GLD3.CONVERSION_TYPE = PE.PROJECT_RATE_TYPE
                                           and GLD3.FROM_CURRENCY = PE.BILL_TRANS_CURRENCY_CODE
                                           and GLD3.TO_CURRENCY = GL.CURRENCY_CODE
                                           and gld3.CONVERSION_DATE  = PE.completion_date) ) ) ))
from DUAL where PE.completioN_date between (select distinct START_DATE from   PA_PERIODS_ALL where PERIOD_NAME =T.PER6) and (select distinct END_DATE from   PA_PERIODS_ALL where PERIOD_NAME =T.PER6))
PER6
,(select
DECODE(PE.BILL_TRANS_CURRENCY_CODE, GL.CURRENCY_CODE, PE.BILL_TRANS_REV_AMOUNT,
         DECODE(PE.PROJECT_RATE_TYPE , 'User', PE.projfunc_revenue_Amount,
                  DECODE(PE.REVENUE_DISTRIBUTED_FLAG , 'Y', (select PE.BILL_TRANS_REV_AMOUNT*GLD.CONVERSION_RATE from GL_DAILY_RATES GLD where
                                                              GLD.CONVERSION_TYPE = PE.PROJECT_RATE_TYPE
                                                              and GLD.FROM_CURRENCY = PE.BILL_TRANS_CURRENCY_CODE
                                                              and GLD.TO_CURRENCY = GL.CURRENCY_CODE
                                                              and GLD.CONVERSION_DATE  = PE.PROJECT_REV_RATE_DATE),
                                                        'N',
                             DECODE( (select PE.BILL_TRANS_REV_AMOUNT*GLD1.CONVERSION_RATE from GL_DAILY_RATES GLD1 where
                                        GLD1.CONVERSION_TYPE = PE.PROJECT_RATE_TYPE
                                        and GLD1.FROM_CURRENCY = PE.BILL_TRANS_CURRENCY_CODE
                                        and GLD1.TO_CURRENCY = GL.CURRENCY_CODE
                                        and gld1.CONVERSION_DATE  = PE.COMPLETION_DATE), null,
                                      (select PE.BILL_TRANS_REV_AMOUNT*GLD2.CONVERSION_RATE from GL_DAILY_RATES GLD2 where
                                         GLD2.CONVERSION_TYPE = GL.PERIOD_END_RATE_TYPE
                                         and GLD2.FROM_CURRENCY = PE.BILL_TRANS_CURRENCY_CODE
                                         and GLD2.TO_CURRENCY = GL.CURRENCY_CODE
                                         and GLD2.CONVERSION_DATE  = (select max(GLD2_1.CONVERSION_DATE) from GL_DAILY_RATES GLD2_1
                                                                        where
                                                                        GLD2_1.CONVERSION_TYPE = GL.PERIOD_END_RATE_TYPE
                                                                        and GLD2_1.FROM_CURRENCY = PE.BILL_TRANS_CURRENCY_CODE
                                                                        and GLD2_1.TO_CURRENCY = GL.CURRENCY_CODE
                                                                      )
                                         ),
                                      (select PE.BILL_TRANS_REV_AMOUNT*GLD3.CONVERSION_RATE from GL_DAILY_RATES GLD3 where
                                           GLD3.CONVERSION_TYPE = PE.PROJECT_RATE_TYPE
                                           and GLD3.FROM_CURRENCY = PE.BILL_TRANS_CURRENCY_CODE
                                           and GLD3.TO_CURRENCY = GL.CURRENCY_CODE
                                           and gld3.CONVERSION_DATE  = PE.completion_date) ) ) ))
from DUAL where PE.completioN_date between (select distinct START_DATE from   PA_PERIODS_ALL where PERIOD_NAME =T.PER7) and (select distinct END_DATE from   PA_PERIODS_ALL where PERIOD_NAME =T.PER7))
PER7
,(select
DECODE(PE.BILL_TRANS_CURRENCY_CODE, GL.CURRENCY_CODE, PE.BILL_TRANS_REV_AMOUNT,
         DECODE(PE.PROJECT_RATE_TYPE , 'User', PE.projfunc_revenue_Amount,
                  DECODE(PE.REVENUE_DISTRIBUTED_FLAG , 'Y', (select PE.BILL_TRANS_REV_AMOUNT*GLD.CONVERSION_RATE from GL_DAILY_RATES GLD where
                                                              GLD.CONVERSION_TYPE = PE.PROJECT_RATE_TYPE
                                                              and GLD.FROM_CURRENCY = PE.BILL_TRANS_CURRENCY_CODE
                                                              and GLD.TO_CURRENCY = GL.CURRENCY_CODE
                                                              and GLD.CONVERSION_DATE  = PE.PROJECT_REV_RATE_DATE),
                                                        'N',
                             DECODE( (select PE.BILL_TRANS_REV_AMOUNT*GLD1.CONVERSION_RATE from GL_DAILY_RATES GLD1 where
                                        GLD1.CONVERSION_TYPE = PE.PROJECT_RATE_TYPE
                                        and GLD1.FROM_CURRENCY = PE.BILL_TRANS_CURRENCY_CODE
                                        and GLD1.TO_CURRENCY = GL.CURRENCY_CODE
                                        and gld1.CONVERSION_DATE  = PE.COMPLETION_DATE), null,
                                      (select PE.BILL_TRANS_REV_AMOUNT*GLD2.CONVERSION_RATE from GL_DAILY_RATES GLD2 where
                                         GLD2.CONVERSION_TYPE = GL.PERIOD_END_RATE_TYPE
                                         and GLD2.FROM_CURRENCY = PE.BILL_TRANS_CURRENCY_CODE
                                         and GLD2.TO_CURRENCY = GL.CURRENCY_CODE
                                         and GLD2.CONVERSION_DATE  = (select max(GLD2_1.CONVERSION_DATE) from GL_DAILY_RATES GLD2_1
                                                                        where
                                                                        GLD2_1.CONVERSION_TYPE = GL.PERIOD_END_RATE_TYPE
                                                                        and GLD2_1.FROM_CURRENCY = PE.BILL_TRANS_CURRENCY_CODE
                                                                        and GLD2_1.TO_CURRENCY = GL.CURRENCY_CODE
                                                                      )
                                         ),
                                      (select PE.BILL_TRANS_REV_AMOUNT*GLD3.CONVERSION_RATE from GL_DAILY_RATES GLD3 where
                                           GLD3.CONVERSION_TYPE = PE.PROJECT_RATE_TYPE
                                           and GLD3.FROM_CURRENCY = PE.BILL_TRANS_CURRENCY_CODE
                                           and GLD3.TO_CURRENCY = GL.CURRENCY_CODE
                                           and gld3.CONVERSION_DATE  = PE.completion_date) ) ) ))
from DUAL where PE.completioN_date between (select distinct START_DATE from   PA_PERIODS_ALL where PERIOD_NAME =T.PER8) and (select distinct END_DATE from   PA_PERIODS_ALL where PERIOD_NAME =T.PER8))
PER8
,(select
DECODE(PE.BILL_TRANS_CURRENCY_CODE, GL.CURRENCY_CODE, PE.BILL_TRANS_REV_AMOUNT,
         DECODE(PE.PROJECT_RATE_TYPE , 'User', PE.projfunc_revenue_Amount,
                  DECODE(PE.REVENUE_DISTRIBUTED_FLAG , 'Y', (select PE.BILL_TRANS_REV_AMOUNT*GLD.CONVERSION_RATE from GL_DAILY_RATES GLD where
                                                              GLD.CONVERSION_TYPE = PE.PROJECT_RATE_TYPE
                                                              and GLD.FROM_CURRENCY = PE.BILL_TRANS_CURRENCY_CODE
                                                              and GLD.TO_CURRENCY = GL.CURRENCY_CODE
                                                              and GLD.CONVERSION_DATE  = PE.PROJECT_REV_RATE_DATE),
                                                        'N',
                             DECODE( (select PE.BILL_TRANS_REV_AMOUNT*GLD1.CONVERSION_RATE from GL_DAILY_RATES GLD1 where
                                        GLD1.CONVERSION_TYPE = PE.PROJECT_RATE_TYPE
                                        and GLD1.FROM_CURRENCY = PE.BILL_TRANS_CURRENCY_CODE
                                        and GLD1.TO_CURRENCY = GL.CURRENCY_CODE
                                        and gld1.CONVERSION_DATE  = PE.COMPLETION_DATE), null,
                                      (select PE.BILL_TRANS_REV_AMOUNT*GLD2.CONVERSION_RATE from GL_DAILY_RATES GLD2 where
                                         GLD2.CONVERSION_TYPE = GL.PERIOD_END_RATE_TYPE
                                         and GLD2.FROM_CURRENCY = PE.BILL_TRANS_CURRENCY_CODE
                                         and GLD2.TO_CURRENCY = GL.CURRENCY_CODE
                                         and GLD2.CONVERSION_DATE  = (select max(GLD2_1.CONVERSION_DATE) from GL_DAILY_RATES GLD2_1
                                                                        where
                                                                        GLD2_1.CONVERSION_TYPE = GL.PERIOD_END_RATE_TYPE
                                                                        and GLD2_1.FROM_CURRENCY = PE.BILL_TRANS_CURRENCY_CODE
                                                                        and GLD2_1.TO_CURRENCY = GL.CURRENCY_CODE
                                                                      )
                                         ),
                                      (select PE.BILL_TRANS_REV_AMOUNT*GLD3.CONVERSION_RATE from GL_DAILY_RATES GLD3 where
                                           GLD3.CONVERSION_TYPE = PE.PROJECT_RATE_TYPE
                                           and GLD3.FROM_CURRENCY = PE.BILL_TRANS_CURRENCY_CODE
                                           and GLD3.TO_CURRENCY = GL.CURRENCY_CODE
                                           and gld3.CONVERSION_DATE  = PE.completion_date) ) ) ))
from DUAL where PE.completioN_date between (select distinct START_DATE from   PA_PERIODS_ALL where PERIOD_NAME =T.PER9) and (select distinct END_DATE from   PA_PERIODS_ALL where PERIOD_NAME =T.PER9))
PER9
,(select
DECODE(PE.BILL_TRANS_CURRENCY_CODE, GL.CURRENCY_CODE, PE.BILL_TRANS_REV_AMOUNT,
         DECODE(PE.PROJECT_RATE_TYPE , 'User', PE.projfunc_revenue_Amount,
                  DECODE(PE.REVENUE_DISTRIBUTED_FLAG , 'Y', (select PE.BILL_TRANS_REV_AMOUNT*GLD.CONVERSION_RATE from GL_DAILY_RATES GLD where
                                                              GLD.CONVERSION_TYPE = PE.PROJECT_RATE_TYPE
                                                              and GLD.FROM_CURRENCY = PE.BILL_TRANS_CURRENCY_CODE
                                                              and GLD.TO_CURRENCY = GL.CURRENCY_CODE
                                                              and GLD.CONVERSION_DATE  = PE.PROJECT_REV_RATE_DATE),
                                                        'N',
                             DECODE( (select PE.BILL_TRANS_REV_AMOUNT*GLD1.CONVERSION_RATE from GL_DAILY_RATES GLD1 where
                                        GLD1.CONVERSION_TYPE = PE.PROJECT_RATE_TYPE
                                        and GLD1.FROM_CURRENCY = PE.BILL_TRANS_CURRENCY_CODE
                                        and GLD1.TO_CURRENCY = GL.CURRENCY_CODE
                                        and gld1.CONVERSION_DATE  = PE.COMPLETION_DATE), null,
                                      (select PE.BILL_TRANS_REV_AMOUNT*GLD2.CONVERSION_RATE from GL_DAILY_RATES GLD2 where
                                         GLD2.CONVERSION_TYPE = GL.PERIOD_END_RATE_TYPE
                                         and GLD2.FROM_CURRENCY = PE.BILL_TRANS_CURRENCY_CODE
                                         and GLD2.TO_CURRENCY = GL.CURRENCY_CODE
                                         and GLD2.CONVERSION_DATE  = (select max(GLD2_1.CONVERSION_DATE) from GL_DAILY_RATES GLD2_1
                                                                        where
                                                                        GLD2_1.CONVERSION_TYPE = GL.PERIOD_END_RATE_TYPE
                                                                        and GLD2_1.FROM_CURRENCY = PE.BILL_TRANS_CURRENCY_CODE
                                                                        and GLD2_1.TO_CURRENCY = GL.CURRENCY_CODE
                                                                      )
                                         ),
                                      (select PE.BILL_TRANS_REV_AMOUNT*GLD3.CONVERSION_RATE from GL_DAILY_RATES GLD3 where
                                           GLD3.CONVERSION_TYPE = PE.PROJECT_RATE_TYPE
                                           and GLD3.FROM_CURRENCY = PE.BILL_TRANS_CURRENCY_CODE
                                           and GLD3.TO_CURRENCY = GL.CURRENCY_CODE
                                           and gld3.CONVERSION_DATE  = PE.completion_date) ) ) ))
from DUAL where PE.completioN_date between (select distinct START_DATE from   PA_PERIODS_ALL where PERIOD_NAME =T.PER10) and (select distinct END_DATE from   PA_PERIODS_ALL where PERIOD_NAME =T.PER10))
PER10
,(select
DECODE(PE.BILL_TRANS_CURRENCY_CODE, GL.CURRENCY_CODE, PE.BILL_TRANS_REV_AMOUNT,
         DECODE(PE.PROJECT_RATE_TYPE , 'User', PE.projfunc_revenue_Amount,
                  DECODE(PE.REVENUE_DISTRIBUTED_FLAG , 'Y', (select PE.BILL_TRANS_REV_AMOUNT*GLD.CONVERSION_RATE from GL_DAILY_RATES GLD where
                                                              GLD.CONVERSION_TYPE = PE.PROJECT_RATE_TYPE
                                                              and GLD.FROM_CURRENCY = PE.BILL_TRANS_CURRENCY_CODE
                                                              and GLD.TO_CURRENCY = GL.CURRENCY_CODE
                                                              and GLD.CONVERSION_DATE  = PE.PROJECT_REV_RATE_DATE),
                                                        'N',
                             DECODE( (select PE.BILL_TRANS_REV_AMOUNT*GLD1.CONVERSION_RATE from GL_DAILY_RATES GLD1 where
                                        GLD1.CONVERSION_TYPE = PE.PROJECT_RATE_TYPE
                                        and GLD1.FROM_CURRENCY = PE.BILL_TRANS_CURRENCY_CODE
                                        and GLD1.TO_CURRENCY = GL.CURRENCY_CODE
                                        and gld1.CONVERSION_DATE  = PE.COMPLETION_DATE), null,
                                      (select PE.BILL_TRANS_REV_AMOUNT*GLD2.CONVERSION_RATE from GL_DAILY_RATES GLD2 where
                                         GLD2.CONVERSION_TYPE = GL.PERIOD_END_RATE_TYPE
                                         and GLD2.FROM_CURRENCY = PE.BILL_TRANS_CURRENCY_CODE
                                         and GLD2.TO_CURRENCY = GL.CURRENCY_CODE
                                         and GLD2.CONVERSION_DATE  = (select max(GLD2_1.CONVERSION_DATE) from GL_DAILY_RATES GLD2_1
                                                                        where
                                                                        GLD2_1.CONVERSION_TYPE = GL.PERIOD_END_RATE_TYPE
                                                                        and GLD2_1.FROM_CURRENCY = PE.BILL_TRANS_CURRENCY_CODE
                                                                        and GLD2_1.TO_CURRENCY = GL.CURRENCY_CODE
                                                                      )
                                         ),
                                      (select PE.BILL_TRANS_REV_AMOUNT*GLD3.CONVERSION_RATE from GL_DAILY_RATES GLD3 where
                                           GLD3.CONVERSION_TYPE = PE.PROJECT_RATE_TYPE
                                           and GLD3.FROM_CURRENCY = PE.BILL_TRANS_CURRENCY_CODE
                                           and GLD3.TO_CURRENCY = GL.CURRENCY_CODE
                                           and gld3.CONVERSION_DATE  = PE.completion_date) ) ) ))
from DUAL where PE.completioN_date between (select distinct START_DATE from   PA_PERIODS_ALL where PERIOD_NAME =T.PER11) and (select distinct END_DATE from   PA_PERIODS_ALL where PERIOD_NAME =T.PER11))
PER11
,(select
DECODE(PE.BILL_TRANS_CURRENCY_CODE, GL.CURRENCY_CODE, PE.BILL_TRANS_REV_AMOUNT,
         DECODE(PE.PROJECT_RATE_TYPE , 'User', PE.projfunc_revenue_Amount,
                  DECODE(PE.REVENUE_DISTRIBUTED_FLAG , 'Y', (select PE.BILL_TRANS_REV_AMOUNT*GLD.CONVERSION_RATE from GL_DAILY_RATES GLD where
                                                              GLD.CONVERSION_TYPE = PE.PROJECT_RATE_TYPE
                                                              and GLD.FROM_CURRENCY = PE.BILL_TRANS_CURRENCY_CODE
                                                              and GLD.TO_CURRENCY = GL.CURRENCY_CODE
                                                              and GLD.CONVERSION_DATE  = PE.PROJECT_REV_RATE_DATE),
                                                        'N',
                             DECODE( (select PE.BILL_TRANS_REV_AMOUNT*GLD1.CONVERSION_RATE from GL_DAILY_RATES GLD1 where
                                        GLD1.CONVERSION_TYPE = PE.PROJECT_RATE_TYPE
                                        and GLD1.FROM_CURRENCY = PE.BILL_TRANS_CURRENCY_CODE
                                        and GLD1.TO_CURRENCY = GL.CURRENCY_CODE
                                        and gld1.CONVERSION_DATE  = PE.COMPLETION_DATE), null,
                                      (select PE.BILL_TRANS_REV_AMOUNT*GLD2.CONVERSION_RATE from GL_DAILY_RATES GLD2 where
                                         GLD2.CONVERSION_TYPE = GL.PERIOD_END_RATE_TYPE
                                         and GLD2.FROM_CURRENCY = PE.BILL_TRANS_CURRENCY_CODE
                                         and GLD2.TO_CURRENCY = GL.CURRENCY_CODE
                                         and GLD2.CONVERSION_DATE  = (select max(GLD2_1.CONVERSION_DATE) from GL_DAILY_RATES GLD2_1
                                                                        where
                                                                        GLD2_1.CONVERSION_TYPE = GL.PERIOD_END_RATE_TYPE
                                                                        and GLD2_1.FROM_CURRENCY = PE.BILL_TRANS_CURRENCY_CODE
                                                                        and GLD2_1.TO_CURRENCY = GL.CURRENCY_CODE
                                                                      )
                                         ),
                                      (select PE.BILL_TRANS_REV_AMOUNT*GLD3.CONVERSION_RATE from GL_DAILY_RATES GLD3 where
                                           GLD3.CONVERSION_TYPE = PE.PROJECT_RATE_TYPE
                                           and GLD3.FROM_CURRENCY = PE.BILL_TRANS_CURRENCY_CODE
                                           and GLD3.TO_CURRENCY = GL.CURRENCY_CODE
                                           and gld3.CONVERSION_DATE  = PE.completion_date) ) ) ))
from DUAL where PE.completioN_date between (select distinct START_DATE from   PA_PERIODS_ALL where PERIOD_NAME =T.PER12) and (select distinct END_DATE from   PA_PERIODS_ALL where PERIOD_NAME =T.PER12))
PER12
,null ABOVE_PER12
,null BEFORE_PER1
,DECODE(PE.BILL_TRANS_CURRENCY_CODE, GL.CURRENCY_CODE, 1,
         DECODE(PE.PROJECT_RATE_TYPE , 'User', PE.PROJECT_EXCHANGE_RATE,
                  DECODE(PE.REVENUE_DISTRIBUTED_FLAG , 'Y', (select GLD.CONVERSION_RATE from GL_DAILY_RATES GLD where
                                                              GLD.CONVERSION_TYPE = PE.PROJECT_RATE_TYPE
                                                              and GLD.FROM_CURRENCY = PE.BILL_TRANS_CURRENCY_CODE
                                                              and GLD.TO_CURRENCY = GL.CURRENCY_CODE
                                                              and GLD.CONVERSION_DATE  = PE.PROJECT_REV_RATE_DATE),
                                                        'N',
                             DECODE( (select GLD1.CONVERSION_RATE from GL_DAILY_RATES GLD1 where
                                        GLD1.CONVERSION_TYPE = PE.PROJECT_RATE_TYPE
                                        and GLD1.FROM_CURRENCY = PE.BILL_TRANS_CURRENCY_CODE
                                        and GLD1.TO_CURRENCY = GL.CURRENCY_CODE
                                        and gld1.CONVERSION_DATE  = PE.COMPLETION_DATE), null,
                                      (select GLD2.CONVERSION_RATE from GL_DAILY_RATES GLD2 where
                                         GLD2.CONVERSION_TYPE = GL.PERIOD_END_RATE_TYPE
                                         and GLD2.FROM_CURRENCY = PE.BILL_TRANS_CURRENCY_CODE
                                         and GLD2.TO_CURRENCY = GL.CURRENCY_CODE
                                         and GLD2.CONVERSION_DATE  = (select max(GLD2_1.CONVERSION_DATE) from GL_DAILY_RATES GLD2_1
                                                                        where
                                                                        GLD2_1.CONVERSION_TYPE = GL.PERIOD_END_RATE_TYPE
                                                                        and GLD2_1.FROM_CURRENCY = PE.BILL_TRANS_CURRENCY_CODE
                                                                        and GLD2_1.TO_CURRENCY = GL.CURRENCY_CODE
                                                                      )
                                         ),
                                      (select GLD3.CONVERSION_RATE from GL_DAILY_RATES GLD3 where
                                           GLD3.CONVERSION_TYPE = PE.PROJECT_RATE_TYPE
                                           and GLD3.FROM_CURRENCY = PE.BILL_TRANS_CURRENCY_CODE
                                           and GLD3.TO_CURRENCY = GL.CURRENCY_CODE
                                           and gld3.CONVERSION_DATE  = PE.completion_date) ) ) ))  exchange_rate,
         DECODE(PE.PROJECT_RATE_TYPE , 'User', null,
                  DECODE(PE.REVENUE_DISTRIBUTED_FLAG , 'Y', (select GLD.CONVERSION_DATE from GL_DAILY_RATES GLD where
                                                              GLD.CONVERSION_TYPE = PE.PROJECT_RATE_TYPE
                                                              and GLD.FROM_CURRENCY = PE.BILL_TRANS_CURRENCY_CODE
                                                              and GLD.TO_CURRENCY = GL.CURRENCY_CODE
                                                              and GLD.CONVERSION_DATE  = PE.PROJECT_REV_RATE_DATE),
                                                        'N',
                             DECODE( (select GLD1.CONVERSION_DATE from GL_DAILY_RATES GLD1 where
                                        GLD1.CONVERSION_TYPE = PE.PROJECT_RATE_TYPE
                                        and GLD1.FROM_CURRENCY = PE.BILL_TRANS_CURRENCY_CODE
                                        and GLD1.TO_CURRENCY = GL.CURRENCY_CODE
                                        and gld1.CONVERSION_DATE  = PE.COMPLETION_DATE), null,
                                      (select GLD2.CONVERSION_DATE from GL_DAILY_RATES GLD2 where
                                         GLD2.CONVERSION_TYPE = GL.PERIOD_END_RATE_TYPE
                                         and GLD2.FROM_CURRENCY = PE.BILL_TRANS_CURRENCY_CODE
                                         and GLD2.TO_CURRENCY = GL.CURRENCY_CODE
                                         and GLD2.CONVERSION_DATE  = (select max(GLD2_1.CONVERSION_DATE) from GL_DAILY_RATES GLD2_1
                                                                        where
                                                                        GLD2_1.CONVERSION_TYPE = GL.PERIOD_END_RATE_TYPE
                                                                        and GLD2_1.FROM_CURRENCY = PE.BILL_TRANS_CURRENCY_CODE
                                                                        and GLD2_1.TO_CURRENCY = GL.CURRENCY_CODE
                                                                      )
                                         ),
                                      (select GLD3.CONVERSION_DATE from GL_DAILY_RATES GLD3 where
                                           GLD3.CONVERSION_TYPE = PE.PROJECT_RATE_TYPE
                                           and GLD3.FROM_CURRENCY = PE.BILL_TRANS_CURRENCY_CODE
                                           and GLD3.TO_CURRENCY = GL.CURRENCY_CODE
                                           and gld3.CONVERSION_DATE  = PE.completion_date) ) ) )
                                           conversion_date
,T.PER13 PERIOD13
,PE.BILL_TRANS_CURRENCY_CODE
,pou.set_of_books_id
,GL.CURRENCY_CODE FUNC_CURRENCY_CODE
,HP.PARTY_NAME CUSTOMER_NAME
,PPA.attribute1 opp_id
, PPA.name PROJECT_NAME_HDR
, PT.TASK_NUMBER TASK_NUMBER_HDR
from PA_PROJECTS_ALL PPA
, PA_TASKS PT
, PA_EVENTS PE
, HR_OPERATING_UNITS POU
--, PA.PA_PROJECTS_ALL PPA_TEMPLATE				-- Commented code by IXPRAVEEN-ARGANO,10-May-2023
, apps.PA_PROJECTS_ALL PPA_TEMPLATE             --  code Added by IXPRAVEEN-ARGANO,   10-May-2023
, PA_PROJECT_PLAYERS_V PPART
, PA_PROJECT_PLAYERS_V PPPVM
, PA_PROJECT_PLAYERS_V PPPOM
, PA_PROJECT_PLAYERS_V PPOOW
, GL_LEDGERS GL
, PA_PROJECT_CUSTOMERS PPC
, HZ_CUST_ACCOUNTS HZA
, hz_parties HP
, (
   select
     p_month PER1
    ,( (select distinct PERIOD_NAME from PA_PERIODS_ALL where START_DATE = ( ADD_MONTHS ( (select distinct START_DATE from PA_PERIODS_ALL where PERIOD_NAME =p_month) , 1)) )  ) PER2
    ,( (select distinct PERIOD_NAME from PA_PERIODS_ALL where START_DATE = ( ADD_MONTHS ( (select distinct START_DATE from PA_PERIODS_ALL where PERIOD_NAME =p_month) , 2)) )  ) PER3
    ,( (select distinct PERIOD_NAME from PA_PERIODS_ALL where START_DATE = ( ADD_MONTHS ( (select distinct START_DATE from PA_PERIODS_ALL where PERIOD_NAME =p_month) , 3)) )  ) PER4
    ,( (select distinct PERIOD_NAME from PA_PERIODS_ALL where START_DATE = ( ADD_MONTHS ( (select distinct START_DATE from PA_PERIODS_ALL where PERIOD_NAME =p_month) , 4)) )  ) PER5
    ,( (select distinct PERIOD_NAME from PA_PERIODS_ALL where START_DATE = ( ADD_MONTHS ( (select distinct START_DATE from PA_PERIODS_ALL where PERIOD_NAME =p_month) , 5)) )  ) PER6
    ,( (select distinct PERIOD_NAME from PA_PERIODS_ALL where START_DATE = ( ADD_MONTHS ( (select distinct START_DATE from PA_PERIODS_ALL where PERIOD_NAME =p_month) , 6)) )  ) PER7
    ,( (select distinct PERIOD_NAME from PA_PERIODS_ALL where START_DATE = ( ADD_MONTHS ( (select distinct START_DATE from PA_PERIODS_ALL where PERIOD_NAME =p_month) , 7)) )  ) PER8
    ,( (select distinct PERIOD_NAME from PA_PERIODS_ALL where START_DATE = ( ADD_MONTHS ( (select distinct START_DATE from PA_PERIODS_ALL where PERIOD_NAME =p_month) , 8)) )  ) PER9
    ,( (select distinct PERIOD_NAME from PA_PERIODS_ALL where START_DATE = ( ADD_MONTHS ( (select distinct START_DATE from PA_PERIODS_ALL where PERIOD_NAME =p_month) , 9)) )  ) PER10
    ,( (select distinct PERIOD_NAME from PA_PERIODS_ALL where START_DATE = ( ADD_MONTHS ( (select distinct START_DATE from PA_PERIODS_ALL where PERIOD_NAME =p_month) , 10)) )  ) PER11
    ,( (select distinct PERIOD_NAME from PA_PERIODS_ALL where START_DATE = ( ADD_MONTHS ( (select distinct START_DATE from PA_PERIODS_ALL where PERIOD_NAME =p_month) , 11)) )  ) PER12
    ,( (select distinct PERIOD_NAME from PA_PERIODS_ALL where START_DATE = ( ADD_MONTHS ( (select distinct START_DATE from PA_PERIODS_ALL where PERIOD_NAME =p_month) , 12)) )  ) PER13
  from DUAL
  ) t
where PPA.PROJECT_ID = PT.PROJECT_ID
and PPC.PROJECT_ID = PPA.PROJECT_ID
and HZa.CUST_ACCOUNT_ID = PPC.CUSTOMER_ID
AND HP.PARTY_ID = HZA.PARTY_ID
and gl.ledger_id = pou.set_of_books_id
and PPA_TEMPLATE.PROJECT_ID = PPA.CREATED_FROM_PROJECT_ID
AND ppa_template.template_flag = 'Y'
and PE.PROJECT_ID  = PPA.PROJECT_ID
and PE.TASK_ID = PT.TASK_ID
and PPART.role(+) ='Project Partner/Director'
AND SYSDATE BETWEEN PPART.START_DATE_ACTIVE(+) AND NVL(PPART.END_DATE_ACTIVE(+), SYSDATE+1)
and PPPVM.role(+) ='Project Manager'
and sysdate between PPPVM.START_DATE_ACTIVE(+) and NVL(PPPVM.END_DATE_ACTIVE(+), sysdate+1)
AND PPPOM.ROLE(+) = 'Project Operations Manager'
AND SYSDATE BETWEEN PPPOM.START_DATE_ACTIVE(+) AND NVL(PPPOM.END_DATE_ACTIVE(+), SYSDATE+1)
and PPOOW.role(+) = 'Opportunity Owner'
AND SYSDATE BETWEEN PPOOW.START_DATE_ACTIVE(+) AND NVL(PPOOW.END_DATE_ACTIVE(+), SYSDATE+1)
and PPA.PROJECT_ID  = PPART.PROJECT_ID(+)
AND PPA.PROJECT_ID  = PPPOM.PROJECT_ID(+)
and PPA.PROJECT_ID  = PPPVM.PROJECT_ID(+)
AND PPA.PROJECT_ID  = PPOOW.PROJECT_ID(+)
and PPA.PROJECT_ID between  NVL(p_project_number_frm, PPA.PROJECT_ID ) and NVL( p_project_number_to, PPA.PROJECT_ID)
and (PE.completioN_date between (select distinct START_DATE from PA_PERIODS_ALL where  PERIOD_NAME = T.PER1) and (select distinct END_DATE from PA_PERIODS_ALL where PERIOD_NAME = T.PER12))
and POU.ORGANIZATION_ID       = PPA.ORG_ID
and PPA.ORG_ID = p_oper_unit
and PPA_TEMPLATE.PROJECT_ID = NVL(p_template, PPA_TEMPLATE.PROJECT_ID)
and nvl(PPART.PERSON_ID,-1) = NVL(p_proj_partner, nvl(PPART.PERSON_ID,-1))
and nvl(PPPVM.PERSON_ID,-1) = NVL(p_project_manager, nvl(PPPVM.PERSON_ID,-1))
and nvl(PPPOM.PERSON_ID,-1) = NVL(p_proj_oper_manager, nvl(PPPOM.PERSON_ID,-1))
and NVL(PPOOW.PERSON_ID,-1) = NVL(p_opp_owner, NVL(PPOOW.PERSON_ID,-1))
union
select distinct PPA.SEGMENT1 PROJECT_NUMBER
, PPA.name PROJECT_NAME
, POU.name
, PPA_TEMPLATE.SEGMENT1 TEMPLATE_NAME
, (select
      LISTAGG(FULL_NAME, '; ') WITHIN GROUP (ORDER BY FULL_NAME)
      from
       PA_PROJECT_PLAYERS_V
      where 1=1
      and role(+) = 'Project Partner/Director'
      and  sysdate between START_DATE_ACTIVE(+) and NVL(END_DATE_ACTIVE(+), sysdate+1)
            and PROJECT_ID = PPART.PROJECT_ID) PARTNER
, (select
      LISTAGG(FULL_NAME, '; ') WITHIN GROUP (ORDER BY FULL_NAME)
      from
       PA_PROJECT_PLAYERS_V
      where 1=1
      and role(+) ='Project Manager'
      and sysdate between START_DATE_ACTIVE(+) and NVL(END_DATE_ACTIVE(+), sysdate+1)
            and PROJECT_ID = PPPVM.PROJECT_ID)  PROJECT_MANAGER
, (select
      LISTAGG(FULL_NAME, '; ') WITHIN GROUP (ORDER BY FULL_NAME)
      from
       PA_PROJECT_PLAYERS_V
      where 1=1
      and role(+) = 'Project Operations Manager'
      and  sysdate between START_DATE_ACTIVE(+) and NVL(END_DATE_ACTIVE(+), sysdate+1)
            and PROJECT_ID = PPPOM.PROJECT_ID) POM
,  (select
      LISTAGG(FULL_NAME, '; ') WITHIN GROUP (ORDER BY FULL_NAME)
      from
       PA_PROJECT_PLAYERS_V
      where 1=1
      and role(+) = 'Opportunity Owner'
      and  sysdate between START_DATE_ACTIVE(+) and NVL(END_DATE_ACTIVE(+), sysdate+1)
            and PROJECT_ID = PPOOW.PROJECT_ID) OPP_OWNER
, PPA.PROJECT_ID
, PT.TASK_NUMBER
, PT.TASK_ID
, PE.EVENT_ID TRANSACTION_ID
, PE.DESCRIPTION
, PE.BILL_AMOUNT, PE.BILL_TRANS_REV_AMOUNT REVENUE_AMOUNT, PE.completioN_date
, T.PER1 PERIOD1
, PE.REVENUE_DISTRIBUTED_FLAG
, PE.PROJECT_CURRENCY_CODE
, PE.ATTRIBUTE1
, null PER1
, null PER2
, null PER3
, null PER4
, null PER5
, null PER6
, null PER7
, null PER8
, null PER9
, null PER10
, null PER11
, null PER12
,(select
DECODE(PE.BILL_TRANS_CURRENCY_CODE, GL.CURRENCY_CODE, PE.BILL_TRANS_REV_AMOUNT,
         DECODE(PE.PROJECT_RATE_TYPE , 'User', PE.projfunc_revenue_Amount,
                  DECODE(PE.REVENUE_DISTRIBUTED_FLAG , 'Y', (select PE.BILL_TRANS_REV_AMOUNT*GLD.CONVERSION_RATE from GL_DAILY_RATES GLD where
                                                              GLD.CONVERSION_TYPE = PE.PROJECT_RATE_TYPE
                                                              and GLD.FROM_CURRENCY = PE.BILL_TRANS_CURRENCY_CODE
                                                              and GLD.TO_CURRENCY = GL.CURRENCY_CODE
                                                              and GLD.CONVERSION_DATE  = PE.PROJECT_REV_RATE_DATE),
                                                        'N',
                             DECODE( (select PE.BILL_TRANS_REV_AMOUNT*GLD1.CONVERSION_RATE from GL_DAILY_RATES GLD1 where
                                        GLD1.CONVERSION_TYPE = PE.PROJECT_RATE_TYPE
                                        and GLD1.FROM_CURRENCY = PE.BILL_TRANS_CURRENCY_CODE
                                        and GLD1.TO_CURRENCY = GL.CURRENCY_CODE
                                        and gld1.CONVERSION_DATE  = PE.COMPLETION_DATE), null,
                                      (select PE.BILL_TRANS_REV_AMOUNT*GLD2.CONVERSION_RATE from GL_DAILY_RATES GLD2 where
                                         GLD2.CONVERSION_TYPE = GL.PERIOD_END_RATE_TYPE
                                         and GLD2.FROM_CURRENCY = PE.BILL_TRANS_CURRENCY_CODE
                                         and GLD2.TO_CURRENCY = GL.CURRENCY_CODE
                                         and GLD2.CONVERSION_DATE  = (select max(GLD2_1.CONVERSION_DATE) from GL_DAILY_RATES GLD2_1
                                                                        where
                                                                        GLD2_1.CONVERSION_TYPE = GL.PERIOD_END_RATE_TYPE
                                                                        and GLD2_1.FROM_CURRENCY = PE.BILL_TRANS_CURRENCY_CODE
                                                                        and GLD2_1.TO_CURRENCY = GL.CURRENCY_CODE
                                                                      )
                                         ),
                                      (select PE.BILL_TRANS_REV_AMOUNT*GLD3.CONVERSION_RATE from GL_DAILY_RATES GLD3 where
                                           GLD3.CONVERSION_TYPE = PE.PROJECT_RATE_TYPE
                                           and GLD3.FROM_CURRENCY = PE.BILL_TRANS_CURRENCY_CODE
                                           and GLD3.TO_CURRENCY = GL.CURRENCY_CODE
                                           and gld3.CONVERSION_DATE  = PE.completion_date) ) ) ))
from DUAL where PE.completioN_date > (select distinct END_DATE from   PA_PERIODS_ALL where PERIOD_NAME =T.PER12))
above_per12
,
null BEFORE_PER1
,
DECODE(PE.BILL_TRANS_CURRENCY_CODE, GL.CURRENCY_CODE, 1,
         DECODE(PE.PROJECT_RATE_TYPE , 'User', PE.PROJECT_EXCHANGE_RATE,
                  DECODE(PE.REVENUE_DISTRIBUTED_FLAG , 'Y', (select GLD.CONVERSION_RATE from GL_DAILY_RATES GLD where
                                                              GLD.CONVERSION_TYPE = PE.PROJECT_RATE_TYPE
                                                              and GLD.FROM_CURRENCY = PE.BILL_TRANS_CURRENCY_CODE
                                                              and GLD.TO_CURRENCY = GL.CURRENCY_CODE
                                                              and GLD.CONVERSION_DATE  = PE.PROJECT_REV_RATE_DATE),
                                                        'N',
                             DECODE( (select GLD1.CONVERSION_RATE from GL_DAILY_RATES GLD1 where
                                        GLD1.CONVERSION_TYPE = PE.PROJECT_RATE_TYPE
                                        and GLD1.FROM_CURRENCY = PE.BILL_TRANS_CURRENCY_CODE
                                        and GLD1.TO_CURRENCY = GL.CURRENCY_CODE
                                        and gld1.CONVERSION_DATE  = PE.COMPLETION_DATE), null,
                                      (select GLD2.CONVERSION_RATE from GL_DAILY_RATES GLD2 where
                                         GLD2.CONVERSION_TYPE = GL.PERIOD_END_RATE_TYPE
                                         and GLD2.FROM_CURRENCY = PE.BILL_TRANS_CURRENCY_CODE
                                         and GLD2.TO_CURRENCY = GL.CURRENCY_CODE
                                         and GLD2.CONVERSION_DATE  = (select max(GLD2_1.CONVERSION_DATE) from GL_DAILY_RATES GLD2_1
                                                                        where
                                                                        GLD2_1.CONVERSION_TYPE = GL.PERIOD_END_RATE_TYPE
                                                                        and GLD2_1.FROM_CURRENCY = PE.BILL_TRANS_CURRENCY_CODE
                                                                        and GLD2_1.TO_CURRENCY = GL.CURRENCY_CODE
                                                                      )
                                         ),
                                      (select GLD3.CONVERSION_RATE from GL_DAILY_RATES GLD3 where
                                           GLD3.CONVERSION_TYPE = PE.PROJECT_RATE_TYPE
                                           and GLD3.FROM_CURRENCY = PE.BILL_TRANS_CURRENCY_CODE
                                           and GLD3.TO_CURRENCY = GL.CURRENCY_CODE
                                           and gld3.CONVERSION_DATE  = PE.completion_date) ) ) ))  exchange_rate,
         DECODE(PE.PROJECT_RATE_TYPE , 'User', null,
                  DECODE(PE.REVENUE_DISTRIBUTED_FLAG , 'Y', (select GLD.CONVERSION_DATE from GL_DAILY_RATES GLD where
                                                              GLD.CONVERSION_TYPE = PE.PROJECT_RATE_TYPE
                                                              and GLD.FROM_CURRENCY = PE.BILL_TRANS_CURRENCY_CODE
                                                              and GLD.TO_CURRENCY = GL.CURRENCY_CODE
                                                              and GLD.CONVERSION_DATE  = PE.PROJECT_REV_RATE_DATE),
                                                        'N',
                             DECODE( (select GLD1.CONVERSION_DATE from GL_DAILY_RATES GLD1 where
                                        GLD1.CONVERSION_TYPE = PE.PROJECT_RATE_TYPE
                                        and GLD1.FROM_CURRENCY = PE.BILL_TRANS_CURRENCY_CODE
                                        and GLD1.TO_CURRENCY = GL.CURRENCY_CODE
                                        and gld1.CONVERSION_DATE  = PE.COMPLETION_DATE), null,
                                      (select GLD2.CONVERSION_DATE from GL_DAILY_RATES GLD2 where
                                         GLD2.CONVERSION_TYPE = GL.PERIOD_END_RATE_TYPE
                                         and GLD2.FROM_CURRENCY = PE.BILL_TRANS_CURRENCY_CODE
                                         and GLD2.TO_CURRENCY = GL.CURRENCY_CODE
                                         and GLD2.CONVERSION_DATE  = (select max(GLD2_1.CONVERSION_DATE) from GL_DAILY_RATES GLD2_1
                                                                        where
                                                                        GLD2_1.CONVERSION_TYPE = GL.PERIOD_END_RATE_TYPE
                                                                        and GLD2_1.FROM_CURRENCY = PE.BILL_TRANS_CURRENCY_CODE
                                                                        and GLD2_1.TO_CURRENCY = GL.CURRENCY_CODE
                                                                      )
                                         ),
                                      (select GLD3.CONVERSION_DATE from GL_DAILY_RATES GLD3 where
                                           GLD3.CONVERSION_TYPE = PE.PROJECT_RATE_TYPE
                                           and GLD3.FROM_CURRENCY = PE.BILL_TRANS_CURRENCY_CODE
                                           and GLD3.TO_CURRENCY = GL.CURRENCY_CODE
                                           and gld3.CONVERSION_DATE  = PE.completion_date) ) ) )--)
                                           conversion_date
,T.PER13 PERIOD13
,PE.BILL_TRANS_CURRENCY_CODE
,pou.set_of_books_id
,GL.CURRENCY_CODE FUNC_CURRENCY_CODE
,HP.PARTY_NAME CUSTOMER_NAME
,PPA.attribute1 opp_id
, PPA.name PROJECT_NAME_HDR
, PT.TASK_NUMBER TASK_NUMBER_HDR
from PA_PROJECTS_ALL PPA
, PA_TASKS PT
, PA_EVENTS PE
, HR_OPERATING_UNITS POU
--, PA.PA_PROJECTS_ALL PPA_TEMPLATE			-- Commented code by IXPRAVEEN-ARGANO,10-May-2023
, apps.PA_PROJECTS_ALL PPA_TEMPLATE           --  code Added by IXPRAVEEN-ARGANO,   10-May-2023
, PA_PROJECT_PLAYERS_V PPART
, PA_PROJECT_PLAYERS_V PPPVM
, PA_PROJECT_PLAYERS_V PPPOM
, PA_PROJECT_PLAYERS_V PPOOW
, GL_LEDGERS GL
, PA_PROJECT_CUSTOMERS PPC
, HZ_CUST_ACCOUNTS HZA
, hz_parties HP
, (
   select
     p_month PER1
    ,( (select distinct PERIOD_NAME from PA_PERIODS_ALL where START_DATE = ( ADD_MONTHS ( (select distinct START_DATE from PA_PERIODS_ALL where PERIOD_NAME =p_month) , 1)) )  ) PER2
    ,( (select distinct PERIOD_NAME from PA_PERIODS_ALL where START_DATE = ( ADD_MONTHS ( (select distinct START_DATE from PA_PERIODS_ALL where PERIOD_NAME =p_month) , 2)) )  ) PER3
    ,( (select distinct PERIOD_NAME from PA_PERIODS_ALL where START_DATE = ( ADD_MONTHS ( (select distinct START_DATE from PA_PERIODS_ALL where PERIOD_NAME =p_month) , 3)) )  ) PER4
    ,( (select distinct PERIOD_NAME from PA_PERIODS_ALL where START_DATE = ( ADD_MONTHS ( (select distinct START_DATE from PA_PERIODS_ALL where PERIOD_NAME =p_month) , 4)) )  ) PER5
    ,( (select distinct PERIOD_NAME from PA_PERIODS_ALL where START_DATE = ( ADD_MONTHS ( (select distinct START_DATE from PA_PERIODS_ALL where PERIOD_NAME =p_month) , 5)) )  ) PER6
    ,( (select distinct PERIOD_NAME from PA_PERIODS_ALL where START_DATE = ( ADD_MONTHS ( (select distinct START_DATE from PA_PERIODS_ALL where PERIOD_NAME =p_month) , 6)) ) ) PER7
    ,( (select distinct PERIOD_NAME from PA_PERIODS_ALL where START_DATE = ( ADD_MONTHS ( (select distinct START_DATE from PA_PERIODS_ALL where PERIOD_NAME =p_month) , 7)) )  ) PER8
    ,( (select distinct PERIOD_NAME from PA_PERIODS_ALL where START_DATE = ( ADD_MONTHS ( (select distinct START_DATE from PA_PERIODS_ALL where PERIOD_NAME =p_month) , 8)) )  ) PER9
    ,( (select distinct PERIOD_NAME from PA_PERIODS_ALL where START_DATE = ( ADD_MONTHS ( (select distinct START_DATE from PA_PERIODS_ALL where PERIOD_NAME =p_month) , 9)) )  ) PER10
    ,( (select distinct PERIOD_NAME from PA_PERIODS_ALL where START_DATE = ( ADD_MONTHS ( (select distinct START_DATE from PA_PERIODS_ALL where PERIOD_NAME =p_month) , 10)) )  ) PER11
    ,( (select distinct PERIOD_NAME from PA_PERIODS_ALL where START_DATE = ( ADD_MONTHS ( (select distinct START_DATE from PA_PERIODS_ALL where PERIOD_NAME =p_month) , 11)) )  ) PER12
    ,( (select distinct PERIOD_NAME from PA_PERIODS_ALL where START_DATE = ( ADD_MONTHS ( (select distinct START_DATE from PA_PERIODS_ALL where PERIOD_NAME =p_month) , 12)) )  ) PER13
  from DUAL
  ) t
where PPA.PROJECT_ID = PT.PROJECT_ID
and PPC.PROJECT_ID = PPA.PROJECT_ID
and HZa.CUST_ACCOUNT_ID = PPC.CUSTOMER_ID
AND HP.PARTY_ID = HZA.PARTY_ID
and gl.ledger_id = pou.set_of_books_id
and PPA_TEMPLATE.PROJECT_ID = PPA.CREATED_FROM_PROJECT_ID
AND ppa_template.template_flag = 'Y'
and PE.PROJECT_ID  = PPA.PROJECT_ID
and PE.TASK_ID = PT.TASK_ID
and PPART.role(+) ='Project Partner/Director'
AND SYSDATE BETWEEN PPART.START_DATE_ACTIVE(+) AND NVL(PPART.END_DATE_ACTIVE(+), SYSDATE+1)
and PPPVM.role(+) ='Project Manager'
and sysdate between PPPVM.START_DATE_ACTIVE(+) and NVL(PPPVM.END_DATE_ACTIVE(+), sysdate+1)
AND PPPOM.ROLE(+) = 'Project Operations Manager'
AND SYSDATE BETWEEN PPPOM.START_DATE_ACTIVE(+) AND NVL(PPPOM.END_DATE_ACTIVE(+), SYSDATE+1)
and PPOOW.role(+) = 'Opportunity Owner'
AND SYSDATE BETWEEN PPOOW.START_DATE_ACTIVE(+) AND NVL(PPOOW.END_DATE_ACTIVE(+), SYSDATE+1)
and PPA.PROJECT_ID  = PPART.PROJECT_ID(+)
AND PPA.PROJECT_ID  = PPPOM.PROJECT_ID(+)
and PPA.PROJECT_ID  = PPPVM.PROJECT_ID(+)
AND PPA.PROJECT_ID  = PPOOW.PROJECT_ID(+)
and PPA.PROJECT_ID between  NVL(p_project_number_frm, PPA.PROJECT_ID ) and NVL( p_project_number_to, PPA.PROJECT_ID)
and (PE.completioN_date >= (select distinct END_DATE from PA_PERIODS_ALL where  PERIOD_NAME = T.PER12))
and POU.ORGANIZATION_ID       = PPA.ORG_ID
and PPA.ORG_ID = p_oper_unit
and PPA_TEMPLATE.PROJECT_ID = NVL(p_template, PPA_TEMPLATE.PROJECT_ID)
and nvl(PPART.PERSON_ID,-1) = NVL(p_proj_partner, nvl(PPART.PERSON_ID,-1))
and nvl(PPPVM.PERSON_ID,-1) = NVL(p_project_manager, nvl(PPPVM.PERSON_ID,-1))
and nvl(PPPOM.PERSON_ID,-1) = NVL(p_proj_oper_manager, nvl(PPPOM.PERSON_ID,-1))
and NVL(PPOOW.PERSON_ID,-1) = NVL(p_opp_owner, NVL(PPOOW.PERSON_ID,-1))
union
select distinct PPA.SEGMENT1 PROJECT_NUMBER
, PPA.name PROJECT_NAME
, POU.name
, PPA_TEMPLATE.SEGMENT1 TEMPLATE_NAME
, (select
      LISTAGG(FULL_NAME, '; ') WITHIN GROUP (ORDER BY FULL_NAME)
      from
       PA_PROJECT_PLAYERS_V
      where 1=1
      and role(+) = 'Project Partner/Director'
      and  sysdate between START_DATE_ACTIVE(+) and NVL(END_DATE_ACTIVE(+), sysdate+1)
            and PROJECT_ID = PPART.PROJECT_ID) PARTNER
, (select
      LISTAGG(FULL_NAME, '; ') WITHIN GROUP (ORDER BY FULL_NAME)
      from
       PA_PROJECT_PLAYERS_V
      where 1=1
      and role(+) ='Project Manager'
      and sysdate between START_DATE_ACTIVE(+) and NVL(END_DATE_ACTIVE(+), sysdate+1)
            and PROJECT_ID = PPPVM.PROJECT_ID)  PROJECT_MANAGER
, (select
      LISTAGG(FULL_NAME, '; ') WITHIN GROUP (ORDER BY FULL_NAME)
      from
       PA_PROJECT_PLAYERS_V
      where 1=1
      and role(+) = 'Project Operations Manager'
      and  sysdate between START_DATE_ACTIVE(+) and NVL(END_DATE_ACTIVE(+), sysdate+1)
            and PROJECT_ID = PPPOM.PROJECT_ID) POM
,  (select
      LISTAGG(FULL_NAME, '; ') WITHIN GROUP (ORDER BY FULL_NAME)
      from
       PA_PROJECT_PLAYERS_V
      where 1=1
      and role(+) = 'Opportunity Owner'
      and  sysdate between START_DATE_ACTIVE(+) and NVL(END_DATE_ACTIVE(+), sysdate+1)
            and PROJECT_ID = PPOOW.PROJECT_ID) OPP_OWNER
, PPA.PROJECT_ID
, PT.TASK_NUMBER
, PT.TASK_ID
, PE.EVENT_ID TRANSACTION_ID
, PE.DESCRIPTION
, PE.BILL_AMOUNT, PE.BILL_TRANS_REV_AMOUNT REVENUE_AMOUNT, PE.completioN_date
, T.PER1 PERIOD1
, PE.REVENUE_DISTRIBUTED_FLAG
, PE.PROJECT_CURRENCY_CODE
, PE.ATTRIBUTE1
,
null
PER1
,
null
PER2
,
null
PER3
,
null
PER4
,
null
PER5
,null
PER6
,null
PER7
,null
PER8
,null
PER9
,null
PER10
,null
PER11
,null
PER12
,
null ABOVE_PER12
,
(select
DECODE(PE.BILL_TRANS_CURRENCY_CODE, GL.CURRENCY_CODE, PE.BILL_TRANS_REV_AMOUNT,
         DECODE(PE.PROJECT_RATE_TYPE , 'User', PE.projfunc_revenue_Amount,
                  DECODE(PE.REVENUE_DISTRIBUTED_FLAG , 'Y', (select PE.BILL_TRANS_REV_AMOUNT*GLD.CONVERSION_RATE from GL_DAILY_RATES GLD where
                                                              GLD.CONVERSION_TYPE = PE.PROJECT_RATE_TYPE
                                                              and GLD.FROM_CURRENCY = PE.BILL_TRANS_CURRENCY_CODE
                                                              and GLD.TO_CURRENCY = GL.CURRENCY_CODE
                                                              and GLD.CONVERSION_DATE  = PE.PROJECT_REV_RATE_DATE),
                                                        'N',
                             DECODE( (select PE.BILL_TRANS_REV_AMOUNT*GLD1.CONVERSION_RATE from GL_DAILY_RATES GLD1 where
                                        GLD1.CONVERSION_TYPE = PE.PROJECT_RATE_TYPE
                                        and GLD1.FROM_CURRENCY = PE.BILL_TRANS_CURRENCY_CODE
                                        and GLD1.TO_CURRENCY = GL.CURRENCY_CODE
                                        and gld1.CONVERSION_DATE  = PE.COMPLETION_DATE), null,
                                      (select PE.BILL_TRANS_REV_AMOUNT*GLD2.CONVERSION_RATE from GL_DAILY_RATES GLD2 where
                                         GLD2.CONVERSION_TYPE = GL.PERIOD_END_RATE_TYPE
                                         and GLD2.FROM_CURRENCY = PE.BILL_TRANS_CURRENCY_CODE
                                         and GLD2.TO_CURRENCY = GL.CURRENCY_CODE
                                         and GLD2.CONVERSION_DATE  = (select max(GLD2_1.CONVERSION_DATE) from GL_DAILY_RATES GLD2_1
                                                                        where
                                                                        GLD2_1.CONVERSION_TYPE = GL.PERIOD_END_RATE_TYPE
                                                                        and GLD2_1.FROM_CURRENCY = PE.BILL_TRANS_CURRENCY_CODE
                                                                        and GLD2_1.TO_CURRENCY = GL.CURRENCY_CODE
                                                                      )),
                                      (select PE.BILL_TRANS_REV_AMOUNT*GLD3.CONVERSION_RATE from GL_DAILY_RATES GLD3 where
                                           GLD3.CONVERSION_TYPE = PE.PROJECT_RATE_TYPE
                                           and GLD3.FROM_CURRENCY = PE.BILL_TRANS_CURRENCY_CODE
                                           and GLD3.TO_CURRENCY = GL.CURRENCY_CODE
                                           and gld3.CONVERSION_DATE  = PE.completion_date) ) ) ))
from DUAL where PE.completioN_date < (select distinct START_DATE from   PA_PERIODS_ALL where PERIOD_NAME =T.PER1))
BEFORE_PER1
,
DECODE(PE.BILL_TRANS_CURRENCY_CODE, GL.CURRENCY_CODE, 1,
         DECODE(PE.PROJECT_RATE_TYPE , 'User', PE.PROJECT_EXCHANGE_RATE,
                  DECODE(PE.REVENUE_DISTRIBUTED_FLAG , 'Y', (select GLD.CONVERSION_RATE from GL_DAILY_RATES GLD where
                                                              GLD.CONVERSION_TYPE = PE.PROJECT_RATE_TYPE
                                                              and GLD.FROM_CURRENCY = PE.BILL_TRANS_CURRENCY_CODE
                                                              and GLD.TO_CURRENCY = GL.CURRENCY_CODE
                                                              and GLD.CONVERSION_DATE  = PE.PROJECT_REV_RATE_DATE),
                                                        'N',
                             DECODE( (select GLD1.CONVERSION_RATE from GL_DAILY_RATES GLD1 where
                                        GLD1.CONVERSION_TYPE = PE.PROJECT_RATE_TYPE
                                        and GLD1.FROM_CURRENCY = PE.BILL_TRANS_CURRENCY_CODE
                                        and GLD1.TO_CURRENCY = GL.CURRENCY_CODE
                                        and gld1.CONVERSION_DATE  = PE.COMPLETION_DATE), null,
                                      (select GLD2.CONVERSION_RATE from GL_DAILY_RATES GLD2 where
                                         GLD2.CONVERSION_TYPE = GL.PERIOD_END_RATE_TYPE
                                         and GLD2.FROM_CURRENCY = PE.BILL_TRANS_CURRENCY_CODE
                                         and GLD2.TO_CURRENCY = GL.CURRENCY_CODE
                                         and GLD2.CONVERSION_DATE  = (select max(GLD2_1.CONVERSION_DATE) from GL_DAILY_RATES GLD2_1
                                                                        where
                                                                        GLD2_1.CONVERSION_TYPE = GL.PERIOD_END_RATE_TYPE
                                                                        and GLD2_1.FROM_CURRENCY = PE.BILL_TRANS_CURRENCY_CODE
                                                                        and GLD2_1.TO_CURRENCY = GL.CURRENCY_CODE
                                                                      )
                                         ),
                                      (select GLD3.CONVERSION_RATE from GL_DAILY_RATES GLD3 where
                                           GLD3.CONVERSION_TYPE = PE.PROJECT_RATE_TYPE
                                           and GLD3.FROM_CURRENCY = PE.BILL_TRANS_CURRENCY_CODE
                                           and GLD3.TO_CURRENCY = GL.CURRENCY_CODE
                                           and gld3.CONVERSION_DATE  = PE.completion_date) ) ) ))  exchange_rate,
         DECODE(PE.PROJECT_RATE_TYPE , 'User', null,
                  DECODE(PE.REVENUE_DISTRIBUTED_FLAG , 'Y', (select GLD.CONVERSION_DATE from GL_DAILY_RATES GLD where
                                                              GLD.CONVERSION_TYPE = PE.PROJECT_RATE_TYPE
                                                              and GLD.FROM_CURRENCY = PE.BILL_TRANS_CURRENCY_CODE
                                                              and GLD.TO_CURRENCY = GL.CURRENCY_CODE
                                                              and GLD.CONVERSION_DATE  = PE.PROJECT_REV_RATE_DATE),
                                                        'N',
                             DECODE( (select GLD1.CONVERSION_DATE from GL_DAILY_RATES GLD1 where
                                        GLD1.CONVERSION_TYPE = PE.PROJECT_RATE_TYPE
                                        and GLD1.FROM_CURRENCY = PE.BILL_TRANS_CURRENCY_CODE
                                        and GLD1.TO_CURRENCY = GL.CURRENCY_CODE
                                        and gld1.CONVERSION_DATE  = PE.COMPLETION_DATE), null,
                                      (select GLD2.CONVERSION_DATE from GL_DAILY_RATES GLD2 where
                                         GLD2.CONVERSION_TYPE = GL.PERIOD_END_RATE_TYPE
                                         and GLD2.FROM_CURRENCY = PE.BILL_TRANS_CURRENCY_CODE
                                         and GLD2.TO_CURRENCY = GL.CURRENCY_CODE
                                         and GLD2.CONVERSION_DATE  = (select max(GLD2_1.CONVERSION_DATE) from GL_DAILY_RATES GLD2_1
                                                                        where
                                                                        GLD2_1.CONVERSION_TYPE = GL.PERIOD_END_RATE_TYPE
                                                                        and GLD2_1.FROM_CURRENCY = PE.BILL_TRANS_CURRENCY_CODE
                                                                        and GLD2_1.TO_CURRENCY = GL.CURRENCY_CODE
                                                                      )
                                         ),
                                      (select GLD3.CONVERSION_DATE from GL_DAILY_RATES GLD3 where
                                           GLD3.CONVERSION_TYPE = PE.PROJECT_RATE_TYPE
                                           and GLD3.FROM_CURRENCY = PE.BILL_TRANS_CURRENCY_CODE
                                           and GLD3.TO_CURRENCY = GL.CURRENCY_CODE
                                           and gld3.CONVERSION_DATE  = PE.completion_date) ) ) )
                                           conversion_date
,T.PER13 PERIOD13
,PE.BILL_TRANS_CURRENCY_CODE
,pou.set_of_books_id
,GL.CURRENCY_CODE FUNC_CURRENCY_CODE
,HP.PARTY_NAME CUSTOMER_NAME
,PPA.attribute1 opp_id
, PPA.name PROJECT_NAME_HDR
, PT.TASK_NUMBER TASK_NUMBER_HDR
from PA_PROJECTS_ALL PPA
, PA_TASKS PT
, PA_EVENTS PE
, HR_OPERATING_UNITS POU
--, PA.PA_PROJECTS_ALL PPA_TEMPLATE				-- Commented code by IXPRAVEEN-ARGANO,10-May-2023
, apps.PA_PROJECTS_ALL PPA_TEMPLATE             --  code Added by IXPRAVEEN-ARGANO,   10-May-2023
, PA_PROJECT_PLAYERS_V PPART
, PA_PROJECT_PLAYERS_V PPPVM
, PA_PROJECT_PLAYERS_V PPPOM
, PA_PROJECT_PLAYERS_V PPOOW
, GL_LEDGERS GL
, PA_PROJECT_CUSTOMERS PPC
, HZ_CUST_ACCOUNTS HZA
, hz_parties HP
, (
   select
     p_month PER1
    ,( (select distinct PERIOD_NAME from PA_PERIODS_ALL where START_DATE = ( ADD_MONTHS ( (select distinct START_DATE from PA_PERIODS_ALL where PERIOD_NAME =p_month) , 1)) )  ) PER2
    ,( (select distinct PERIOD_NAME from PA_PERIODS_ALL where START_DATE = ( ADD_MONTHS ( (select distinct START_DATE from PA_PERIODS_ALL where PERIOD_NAME =p_month) , 2)) )  ) PER3
    ,( (select distinct PERIOD_NAME from PA_PERIODS_ALL where START_DATE = ( ADD_MONTHS ( (select distinct START_DATE from PA_PERIODS_ALL where PERIOD_NAME =p_month) , 3)) )  ) PER4
    ,( (select distinct PERIOD_NAME from PA_PERIODS_ALL where START_DATE = ( ADD_MONTHS ( (select distinct START_DATE from PA_PERIODS_ALL where PERIOD_NAME =p_month) , 4)) )  ) PER5
    ,( (select distinct PERIOD_NAME from PA_PERIODS_ALL where START_DATE = ( ADD_MONTHS ( (select distinct START_DATE from PA_PERIODS_ALL where PERIOD_NAME =p_month) , 5)) )  ) PER6
    ,( (select distinct PERIOD_NAME from PA_PERIODS_ALL where START_DATE = ( ADD_MONTHS ( (select distinct START_DATE from PA_PERIODS_ALL where PERIOD_NAME =p_month) , 6)) )  ) PER7
    ,( (select distinct PERIOD_NAME from PA_PERIODS_ALL where START_DATE = ( ADD_MONTHS ( (select distinct START_DATE from PA_PERIODS_ALL where PERIOD_NAME =p_month) , 7)) )  ) PER8
    ,( (select distinct PERIOD_NAME from PA_PERIODS_ALL where START_DATE = ( ADD_MONTHS ( (select distinct START_DATE from PA_PERIODS_ALL where PERIOD_NAME =p_month) , 8)) )  ) PER9
    ,( (select distinct PERIOD_NAME from PA_PERIODS_ALL where START_DATE = ( ADD_MONTHS ( (select distinct START_DATE from PA_PERIODS_ALL where PERIOD_NAME =p_month) , 9)) )  ) PER10
    ,( (select distinct PERIOD_NAME from PA_PERIODS_ALL where START_DATE = ( ADD_MONTHS ( (select distinct START_DATE from PA_PERIODS_ALL where PERIOD_NAME =p_month) , 10)) )  ) PER11
    ,( (select distinct PERIOD_NAME from PA_PERIODS_ALL where START_DATE = ( ADD_MONTHS ( (select distinct START_DATE from PA_PERIODS_ALL where PERIOD_NAME =p_month) , 11)) )  ) PER12
    ,( (select distinct PERIOD_NAME from PA_PERIODS_ALL where START_DATE = ( ADD_MONTHS ( (select distinct START_DATE from PA_PERIODS_ALL where PERIOD_NAME =p_month) , 12)) )  ) PER13
from DUAL) t
where PPA.PROJECT_ID = PT.PROJECT_ID
and PPC.PROJECT_ID = PPA.PROJECT_ID
and HZa.CUST_ACCOUNT_ID = PPC.CUSTOMER_ID
AND HP.PARTY_ID = HZA.PARTY_ID
and gl.ledger_id = pou.set_of_books_id
and PPA_TEMPLATE.PROJECT_ID = PPA.CREATED_FROM_PROJECT_ID
AND ppa_template.template_flag = 'Y'
and PE.PROJECT_ID  = PPA.PROJECT_ID
and PE.TASK_ID = PT.TASK_ID
and PPART.role(+) ='Project Partner/Director'
AND SYSDATE BETWEEN PPART.START_DATE_ACTIVE(+) AND NVL(PPART.END_DATE_ACTIVE(+), SYSDATE+1)
and PPPVM.role(+) ='Project Manager'
and sysdate between PPPVM.START_DATE_ACTIVE(+) and NVL(PPPVM.END_DATE_ACTIVE(+), sysdate+1)
AND PPPOM.ROLE(+) = 'Project Operations Manager'
AND SYSDATE BETWEEN PPPOM.START_DATE_ACTIVE(+) AND NVL(PPPOM.END_DATE_ACTIVE(+), SYSDATE+1)
and PPOOW.role(+) = 'Opportunity Owner'
AND SYSDATE BETWEEN PPOOW.START_DATE_ACTIVE(+) AND NVL(PPOOW.END_DATE_ACTIVE(+), SYSDATE+1)
and PPA.PROJECT_ID  = PPART.PROJECT_ID(+)
AND PPA.PROJECT_ID  = PPPOM.PROJECT_ID(+)
and PPA.PROJECT_ID  = PPPVM.PROJECT_ID(+)
AND PPA.PROJECT_ID  = PPOOW.PROJECT_ID(+)
and PPA.PROJECT_ID between  NVL(p_project_number_frm, PPA.PROJECT_ID ) and NVL( p_project_number_to, PPA.PROJECT_ID)
and (PE.completioN_date < (select distinct START_DATE from PA_PERIODS_ALL where  PERIOD_NAME = T.PER1))
and POU.ORGANIZATION_ID       = PPA.ORG_ID
and PPA.ORG_ID = p_oper_unit
and PPA_TEMPLATE.PROJECT_ID = NVL(p_template, PPA_TEMPLATE.PROJECT_ID)
and nvl(PPART.PERSON_ID,-1) = NVL(p_proj_partner, nvl(PPART.PERSON_ID,-1))
and nvl(PPPVM.PERSON_ID,-1) = NVL(p_project_manager, nvl(PPPVM.PERSON_ID,-1))
and nvl(PPPOM.PERSON_ID,-1) = NVL(p_proj_oper_manager, nvl(PPPOM.PERSON_ID,-1))
and NVL(PPOOW.PERSON_ID,-1) = NVL(p_opp_owner, NVL(PPOOW.PERSON_ID,-1))
);

COMMIT;

EXCEPTION
	WHEN OTHERS THEN
	   Fnd_File.put_line(Fnd_File.log,' In the final exception:  ' || sqlerrm );
	   --APP_EXCEPTION.RAISE_EXCEPTION;
END TTEC_B02C_PRC; --#1

END TTEC_B02C_REP_EXT_PKG;
/
show errors;
/