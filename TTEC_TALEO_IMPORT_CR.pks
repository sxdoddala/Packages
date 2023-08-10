create or replace PACKAGE      ttec_taleo_import_CR
AUTHID CURRENT_USER IS
-- /* $Header: ttec_taleo_import_CR.pkb 1.0 2009/05/21 chchan ship $ */
--
-- /*== START ================================================================================================*\
--    Author: Christiane Chan
--      Date: 21-MAY-2009
-- Call From: ttec_taleo_import
--      Desc: This is an extension of the core ttec_taleo_import package for country specific data validation
--
--     Parameter Description:
--       Parameter values are passed from ttec_taleo_import.processx
--
--   Modification History:
--
--  Version    Date     Author   Description (Include Ticket--)
--  -------  --------  --------  ------------------------------------------------------------------------------
--      1.0  5/21/09   CChan     Initial Version
--      1.1  7/19/13   Kaushik   code changes for PRG implementation project (Hire & Rehire) for employee in countries
--                                                        PRG Australia
--                                                        PRG Belgium
--                                                        PRG Brazil
--                                                        PRG Germany
--                                                        PRG Kuwait
--                                                        PRG Lebanon
--                                                        PRG Singapore
--                                                        PRG South Africa
--                                                        PRG Turkey
--                                                        PRG UAE
--                                                        PRG United Kingdom
--     1.0  17/07/2023 RXNETHI-ARGANO  R12.2 Upgrade Remediation
-- \*== END =====================================
----------------------------------------------------------------------------------------------
/* Version 1.7 - Costa Rica SPECIFIC PROCEDURES -- DEVELOPED FOR ITS INTEGRATION ON MAY2009 */
----------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------
--PROCEDURE ss_cr_validate
--Author: Christiane Chan
--Date:  May 21, 2009
--Parameters:
--Description: This procedure validates that the number provided for National Identifier
--             is correct in length and format.
--
   PROCEDURE ss_validate (
      p_candidate_id        IN  NUMBER,
      p_ss                  IN  VARCHAR2,
      p_country_of_birth    IN  VARCHAR2,
      p_prg_flag            IN  VARCHAR2,               --1.1
      p_ss_out              OUT VARCHAR2,
      p_stat                OUT NUMBER,
      --p_defaults_rec     IN OUT cust.ttec_taleo_defaults%ROWTYPE,  --code commented by RXNETHI-ARGANO,17/07/23
      p_defaults_rec     IN OUT apps.ttec_taleo_defaults%ROWTYPE,    --code added by RXNETHI-ARGANO,17/07/23
      --p_stage_rec        IN OUT cust.ttec_taleo_stage%ROWTYPE      --code commented by RXNETHI-ARGANO,17/07/23
      p_stage_rec        IN OUT apps.ttec_taleo_stage%ROWTYPE        --code added by RXNETHI-ARGANO,17/07/23
   );

   PROCEDURE address_validate (
      p_candidate_id        IN       NUMBER,
      p_address             IN       VARCHAR2,
      p_address2            IN       VARCHAR2,
      p_city                IN       VARCHAR2,
      p_countrycode         IN       VARCHAR2,
      p_county              OUT      VARCHAR2,
      p_stat                OUT      NUMBER,
      --p_defaults_rec     IN OUT cust.ttec_taleo_defaults%ROWTYPE,  --code commented by RXNETHI-ARGANO,17/07/23
      p_defaults_rec     IN OUT apps.ttec_taleo_defaults%ROWTYPE,    --code added by RXNETHI-ARGANO,17/07/23
      --p_stage_rec        IN OUT cust.ttec_taleo_stage%ROWTYPE      --code commented by RXNETHI-ARGANO,17/07/23
      p_stage_rec        IN OUT apps.ttec_taleo_stage%ROWTYPE        --code added by RXNETHI-ARGANO,17/07/23
   );
   PROCEDURE candidate_duplication_validate (
      p_candidate_id        IN       NUMBER,
      p_cand_first_name     IN       VARCHAR2,
      p_cand_last_name      IN       VARCHAR2,
      p_oracle_ssn          IN       VARCHAR2,
      p_business_group      IN       NUMBER,
      p_stat                OUT      NUMBER,
      p_reference8       IN OUT      VARCHAR2,
      --p_stage_rec        IN OUT cust.ttec_taleo_stage%ROWTYPE   --code commented by RXNETHI-ARGANO,17/07/23
      p_stage_rec        IN OUT apps.ttec_taleo_stage%ROWTYPE     --code added by RXNETHI-ARGANO,17/07/23
   );
PROCEDURE shift_validate (
      p_candidate_id        IN       NUMBER,
      p_shift               IN       VARCHAR2,
      p_prg_flag            IN       VARCHAR2,               --1.1
      p_stat                OUT      NUMBER,
      --p_stage_rec        IN OUT cust.ttec_taleo_stage%ROWTYPE   --code commented by RXNETHI-ARGANO,17/07/23
      p_stage_rec        IN OUT apps.ttec_taleo_stage%ROWTYPE     --code added by RXNETHI-ARGANO,17/07/23
   );
PROCEDURE person_type_validate (
      p_candidate_id        IN       NUMBER,
      p_person_type         IN       VARCHAR2,
      p_business_group      IN       VARCHAR2,
      p_stat                OUT      NUMBER,
      --p_stage_rec        IN OUT cust.ttec_taleo_stage%ROWTYPE   --code commented by RXNETHI-ARGANO,17/07/23
      p_stage_rec        IN OUT apps.ttec_taleo_stage%ROWTYPE     --code added by RXNETHI-ARGANO,17/07/23
   );
END ttec_taleo_import_CR;
/
show errors;
/