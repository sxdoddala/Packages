create or replace PACKAGE BODY      ttec_ap_cc_txns_pkg AS
  /* $Header: TTEC_AP_CC_TXNS_PKG.pkb 1.0 2012/04/18 mdodge ship $ */

  /*== START ================================================================================================*\
     Author: Michelle Dodge
       Date: 04/18/2012
  Call From: 'TeleTech American Express Transaction Loader%' SQL*Loader Conc Programs
       Desc: This package will provide functions to build values for the
             AP_CREDIT_CARD_TRXNS_ALL table.

	Modification History:

   Version    Date     Author   Description (Include Ticket#)
   -------  --------  --------  ------------------------------------------------------------------------------
       1.0  04/18/12  MDodge    I #1445347 : Amex CC Transactions - Initial Version.
       1.1  02/25/12  Kgonuguntla I# 2197277: For loading new AMEX transactions, Fixed code to identify
                                              GUIDON location employee transaction
       1.2  04/04/14  Deebak K	As part of PSA-II, Card program id for GUIDON has been changed from 10043 to 10185
       1.3  06/09/14  C.Chan    eLoyalty Add on
       1.4  08/25/14  C.Chan    iKnowtion Add on
       1.5  12/09/14  C.Chan    TSG Add on
       1.6  01/21/14  C.Chan    Rewrite logic to increase the BCA Validation up to 15 digits number and validate against the
                                ap.ap_card_programs_all directly to eliminate the need of updating this package
                                when rolling out a new card program
	1.0	   16-May-2023 IXPRAVEEN(ARGANO)   		R12.2 Upgrade Remediation							
  \*== END ==================================================================================================*/

  -- This function will take an input string from the SQL*Loader [Position(2:203)]
  -- and return a 5 digit card_program_id for Amex US transactions.
  FUNCTION get_amex_card_program_id( p_string IN VARCHAR2 )
    RETURN VARCHAR IS

	v_card_program_id   VARCHAR2( 5 );

  BEGIN

--	SELECT DECODE( SUBSTR( p_string, 11, 5 )
--                 , '71002', 10142
--                 , '01001', 10042
--                 , '01000', 10043
--                 --, '61006', 10043       --v1.1 commented for v1.2 changes
--                 , '61006', 10185       --v1.2
--                 , '01004', 10062
--                 , '21009', 10102
--                 , '31000', 10083
--                 , '31001', 10082
--                 , '31002', 10084
--                 , '01009', 10162
--                 , '11009', 10222      -- v1.3 American Express- eLoyalty LLC
--                 , '71004', 10182      -- v1.4 American Express- iKnowtion
--                 , '21009', 10242      -- v1.5 American Express- TSG
--                 , '11003', DECODE( SUBSTR( p_string, 178, 2 ), '02', 10020, 10000 )
--                 , 99999 )
--      INTO v_card_program_id
--      FROM DUAL;

    /* Formatted on 2015/01/21 09:06 (Formatter Plus v4.8.8) */
    SELECT card_program_id
      INTO v_card_program_id
      --FROM ap.ap_card_programs_all		-- Commented code by IXPRAVEEN-ARGANO,16-May-2023
      FROM apps.ap_card_programs_all        --  code Added by IXPRAVEEN-ARGANO,   16-May-2023
     WHERE attribute4 = SUBSTR (p_string,1,15)
     AND ROWNUM < 2
     ORDER BY last_update_date;

	RETURN v_card_program_id;

  EXCEPTION
    WHEN OTHERS THEN
      RETURN 99999;
  END get_amex_card_program_id;

  -- This function will take an input string from the SQL*Loader [Position(2:203)]
  -- and return a 5 digit card_program_id for Amex CAN Transactions.

  FUNCTION get_can_amex_card_program_id( p_string IN VARCHAR2 )
    RETURN VARCHAR IS

	v_card_program_id   VARCHAR2( 5 );

  BEGIN

--	SELECT DECODE( SUBSTR( p_string, 11, 5 ), '01008', 10122, 10122 )
--      INTO v_card_program_id
--      FROM DUAL;

    SELECT card_program_id
      INTO v_card_program_id
      --FROM ap.ap_card_programs_all				-- Commented code by IXPRAVEEN-ARGANO,16-May-2023
      FROM apps.ap_card_programs_all                --  code Added by IXPRAVEEN-ARGANO,   16-May-2023
     WHERE attribute4 = SUBSTR (p_string,1,15)
     AND ROWNUM < 2
     ORDER BY last_update_date;

	RETURN v_card_program_id;

  EXCEPTION
    WHEN OTHERS THEN
      RETURN 10122;
  END get_can_amex_card_program_id;

END ttec_ap_cc_txns_pkg;
/
show errors;
/