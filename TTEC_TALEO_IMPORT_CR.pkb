create or replace PACKAGE BODY      ttec_taleo_import_CR
IS
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
--      2.1  7/7/2010  CChan     Hirepoint Integration Enhancements Q2 - IB013
--      2.2  7/19/13   Kaushik   code changes for PRG implementation project (Hire & Rehire) for employee in countries
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
--    1.0   17/07/2023  RXNETHI-ARGANO     R12.2 Upgrade Remediation
-- \*== END =====================================

--v_module_name       cust.ttec_error_handling.module_name%TYPE:= NULL;  --code commented by RXNETHI-ARGANO,17/07/23
v_module_name       apps.ttec_error_handling.module_name%TYPE:= NULL;    --code added by RXNETHI-ARGANO,17/07/23
------------------------------------------------------------------------------------------------
/* Version 1.7 - Costa Rica SPECIFIC PROCEDURES -- DEVELOPED FOR ITS INTEGRATION ON MAY2009 */
----------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------
--  PROCEDURE ss_validate
--  Author: Christiane Chan
--  Date:  May 21, 2009
--  Parameters:
--  Description: This procedure validates that the number provided for National Identifier
--               is correct in length and format.
--
--  ===============================
--  For native Costa Rica Citizens:
--  ===============================
--
--  The ID number consists of en digits in three groups (2-4-4),
--  zeros need to be added to complete each group (if necessary),
--  for government reporting.
--
--   For example, a candidate might enter his ID number as 1-741-578,
--   and this needs to be formatted to 0107410578 (ten digits with no hyphens).
--
--  ===============================
--  For  Foreign candidates:
--  ===============================
--
--  Foreign candidates that can work in Costa Rica have a "Permanent Residence"
--  ID issued by the Costa Rica government. This ID has a number which has
--  between 12-17 digits (no hyphens) and doesn't have the same special
--  consideration than the national ID.
--
--  This field can be used to determine rehire eligibility if it matches a National Identifier already present in Oracle belonging to an ex-employee.
--
------------------------------------------------------------------------------------------------
   PROCEDURE ss_validate (
      p_candidate_id        IN  NUMBER,
      p_ss                  IN  VARCHAR2,
      p_country_of_birth    IN  VARCHAR2,
      p_prg_flag            IN  VARCHAR2,               --v2.2
      p_ss_out              OUT VARCHAR2,
      p_stat                OUT NUMBER,
      --p_defaults_rec     IN OUT cust.ttec_taleo_defaults%ROWTYPE,  --code commented by RXNETHI-ARGANO,17/07/23
      p_defaults_rec     IN OUT apps.ttec_taleo_defaults%ROWTYPE,    --code added by RXNETHI-ARGANO,17/07/23
      --p_stage_rec        IN OUT cust.ttec_taleo_stage%ROWTYPE      --code commented by RXNETHI-ARGANO,17/07/23
      p_stage_rec        IN OUT apps.ttec_taleo_stage%ROWTYPE        --code added by RXNETHI-ARGANO,17/07/23
   )
   IS
      l_ss                  VARCHAR2 (64);
      l_ss2                 VARCHAR2 (64);
      l_ss_out              VARCHAR2 (64);
      l_x                   VARCHAR2 (8);
      l_country_of_birth    VARCHAR2 (2);
      l_dash_count          NUMBER   := 0;
      l_stat                NUMBER   := 0; -- error control variable ( 0 = OK, 1 = ERROR)


   BEGIN

      v_module_name := 'CR National Identifier Validate Routine';

      ttec_taleo_import.print_line (v_module_name);
      l_ss := p_ss;

      /* need to rename the procedure below and make it generic */

      IF p_prg_flag = 'Y'       --v2.2
      THEN
         l_stat := 0;
      ELSE
            IF TRIM (l_ss) IS NULL
             THEN
                 --blank
                 l_stat := 1;

            ELSE

              -- The country in which the employee was born.
              -- Helps tell whether the employee is from Costa Rica or foreign.

              ttec_taleo_import.country_of_birth_validate (p_candidate_id,
                                                           p_country_of_birth,
                                                           l_country_of_birth,
                                                           l_stat);
              -- Validate Country of birth first
              IF l_stat = 0 -- This stat is to evaluate if the country of birth is valid
              THEN
                    IF p_country_of_birth = 'CR'
                        -- For native Costa Rica Citizens
                      THEN
                         l_dash_count := sign(INSTR(l_ss,'-',1,1))+ SIGN( INSTR(l_ss,'-',1,2))+SIGN(INSTR(l_ss,'-',1,3));
                          -- Will fail if it does not have 2 hyphen and less than 12 digits
                         IF l_dash_count > 0
                         THEN
                              IF l_dash_count = 2
                              THEN
                                 IF  LENGTH (l_ss) <= 12
                                 THEN

                                   -- LPAD with zero(s) digits between hyphens to meet this format ZZ-ZZZZ-ZZZZ
                                   l_ss2 :=   lpad(ltrim(rtrim(substr(l_ss,1,instr(l_ss,'-',1)-1))),2,'0')
                                           || lpad(ltrim(rtrim(substr(l_ss,instr(l_ss,'-',1,1)+1,instr(l_ss,'-',1,2)-(instr(l_ss,'-',1,1)+1)))),4,'0')
                                           || lpad(ltrim(rtrim(substr(l_ss,instr(l_ss,'-',1,2)+1))),4,'0');

                                   -- Validate the data type of the social security number.
                                   -- A valid social security number contains ten digits with no hyphens.

                                   BEGIN
                                      SELECT 'X'
                                        INTO l_x
                                        FROM DUAL
                                      WHERE REGEXP_LIKE (l_ss2, '^([[:digit:]]{10})$');
                                      -- 10 digits, correct format

                                   EXCEPTION
                                   WHEN OTHERS
                                    THEN
                                       --
                                       l_stat := 2;
                                    END;
                                 ELSE
                                     -- Not meeting the native Costa Rica Citizens SSN format ZZ-ZZZZ-ZZZZ either not having 2 hyphens or Wrong number of digits
                                    l_stat := 2;
                                 END IF;
                              ELSE
                                  -- Not meeting the native Costa Rica Citizens SSN format ZZ-ZZZZ-ZZZZ either not having 2 hyphens or Wrong number of digits
                                 l_stat := 2;
                              END IF;

                         ELSE

                             IF LENGTH (l_ss) != 10 THEN
                                  -- Not meeting the native Costa Rica Citizens SSN format ZZ-ZZZZ-ZZZZ either not having 2 hyphens or Wrong number of digits
                                 l_stat := 2;
                             ELSE
                                 l_ss2 := l_ss;
                             END IF;

                         END IF;


                    ELSE  -- Foreign candidates that can work in Costa Rica have a "Permanent Residence" ID issued by the Costa Rica government.
                            -- This ID has a number which has between 12-17 digits (no hyphens) and doesn't have the same special consideration
                            -- than the national ID.


                         -- Remove spaces and hyphens
                         l_ss2 := REPLACE (l_ss, '-');
                         l_ss2 := REPLACE (l_ss2, ' ');

                         IF LENGTH (l_ss2) < 12 or LENGTH (l_ss2) > 17
                         THEN
                             -- wrong number of digits
                            l_stat := 3;

                         END IF;
                    END IF;
              ELSE -- The validation for country of birth has failed
                       l_stat := 4;
              END IF;
            END IF;
        -- If ssn is numeric and 18 numbers in length, and birth date and gender matches,
        -- then it is ok.
      END IF;           --v2.2

      IF l_stat = 0
      THEN
         p_ss_out := l_ss2;

      ELSE
         -- If the social security number does not contain the correct number of digits
         -- return the following message and pick up the valid value from the valid data
         -- user defined table to continue processing
         p_ss_out := p_defaults_rec.ssnumber;
         p_stage_rec.emp_val_err := 1;
                -- do not process defaulted values
      END IF;

      p_stage_rec.ssnumber := p_ss_out;
      p_stat := l_stat;

   END ss_validate;
/*
------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------
--  PROCEDURE address_validate
--  Author: Christiane Chan
--  Date:  May 21, 2009
--  Parameters:
--  Description: Costa Rica Address Validation
--
--  Address Line 1 	    : In Costa Rica, only one line is used to enter the Adress in Oracle.
--  Address Line 2 	    : Not used in Costa Rica
--  Town 		        : City where the employee lives.
--  Postal Code 	    : Not required for Costa Rica. Costa Rica doesn't have zip codes.
--  Telephone Number 1	: Candidate primary phone number. It is usual practice, and strongly encouraged for the employee to provide a Telephone Number. But in the rare case the employee can't provide it, the field can be left blank.
--  Country Description : Not used in Costa Rica.
--  Country Code	    : This code is the one fed into the country field in the address form for Costa Rica.
--  State Description	: Not used in Costa Rica.
--  State/Province Code	: Not used in Costa Rica.
------------------------------------------------------------------------------------------------
*/
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
   )
   IS
      l_stat                NUMBER        := 0;
      l_address             VARCHAR (256) := NULL;
      l_address2            VARCHAR (256) := NULL;
      l_city                VARCHAR (64)  := NULL;
      l_country             VARCHAR (64)  := NULL;
      l_countrycode         VARCHAR (64)  := NULL;
      l_x                   VARCHAR (64);
   BEGIN


      v_module_name := 'Costa Rica Address Validate Routine';

      ttec_taleo_import.print_line (v_module_name);
      p_county := NULL;

      IF TRIM (p_address) IS NULL
      THEN
         -- no street address is given by candidate
         l_stat := 1;
      END IF;

      IF TRIM (p_city) IS NULL
      THEN
      -- no city town is given by candidate
         l_stat := 2;
      END IF;

      IF TRIM (p_countrycode) IS NULL
      THEN
         -- no Country Code is given by candidate
         l_stat := 3;
      END IF;

     /* Version 2.1 Begin*/
      IF TRIM (p_address2) IS NULL
      THEN
         -- The address line 2 (Neighborhood / House number) for the candidate is missing
         l_stat := 4;
      END IF;
     /* Version 2.1 End*/

      -- write to stage if error in address get the defaults
      IF l_stat = 0
      THEN
         l_address      := p_address;
         l_address2     := p_address2;
         l_city         := p_city;
         l_countrycode  := p_countrycode;
      ELSE
         l_address      := p_defaults_rec.address;
         l_address2     := p_defaults_rec.address2;
         l_city         := p_defaults_rec.city;
         l_countrycode  := p_defaults_rec.countrycode;
         p_stage_rec.emp_val_err := 1;         -- do not process defaulted values
      END IF;

      p_stage_rec.address       := l_address;
      p_stage_rec.address2      := l_address2;
      p_stage_rec.city          := l_city;
      p_stage_rec.countrycode   := l_countrycode;

      p_stat := l_stat;
   END;
/*
------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------
--  PROCEDURE candidate_duplication_validate
--  Author: Christiane Chan
--  Date:  June 24, 2009
--  Parameters:
--  Description: Costa Rica Candidate Duplication Validation
--
------------------------------------------------------------------------------------------------
*/
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
   ) IS
      l_employee_number       per_all_people_f.employee_number%TYPE;
      l_rehire                VARCHAR2 (64) := 'YES';
      l_stat                  NUMBER := 0;

     CURSOR c_dup_cand_name_ssn IS
             SELECT papf.employee_number
             FROM  per_all_people_f papf
                 , per_person_types ppt
             WHERE papf.person_type_id = ppt.person_type_id
               AND papf.national_identifier       = p_oracle_ssn
               AND UPPER(TRIM(papf.first_name))   = UPPER(TRIM(p_cand_first_name))
               AND UPPER(TRIM(papf.last_name))    = UPPER(TRIM(p_cand_last_name))
               AND ppt.user_person_type = 'Employee'
               AND papf.effective_start_date =
                                        (SELECT MAX (a.effective_start_date)
                                           FROM per_all_people_f a
                                          WHERE a.person_id = papf.person_id)
               AND papf.business_group_id = p_business_group;

     CURSOR c_dup_cand_name IS
             SELECT papf.employee_number
             FROM  per_all_people_f papf
                 , per_person_types ppt
             WHERE papf.person_type_id            = ppt.person_type_id
               AND papf.national_identifier      != p_oracle_ssn
               AND UPPER(TRIM(papf.first_name))   = UPPER(TRIM(p_cand_first_name))
               AND UPPER(TRIM(papf.last_name))    = UPPER(TRIM(p_cand_last_name))
               AND ppt.user_person_type = 'Employee'
               AND papf.effective_start_date =
                                        (SELECT MAX (a.effective_start_date)
                                           FROM per_all_people_f a
                                          WHERE a.person_id = papf.person_id)
               AND papf.business_group_id = p_business_group;

BEGIN

      v_module_name := 'Costa Rica Duplicate Candidate Validate Routine';
      ttec_taleo_import.print_line (v_module_name);

      OPEN c_dup_cand_name_ssn;

      FETCH c_dup_cand_name_ssn
       INTO l_employee_number;

      IF c_dup_cand_name_ssn%FOUND
      THEN
         p_reference8 := l_employee_number;
         l_stat := 1;

      END IF;

      CLOSE c_dup_cand_name_ssn;


      OPEN c_dup_cand_name;

      FETCH c_dup_cand_name
       INTO l_employee_number;

      IF c_dup_cand_name%FOUND
      THEN
         p_reference8 := l_employee_number; -- duplicate names but different ssn found - create emp record with Warning message
         l_stat := 2;
      END IF;

      CLOSE c_dup_cand_name;

      IF l_stat = 1 THEN
         p_stage_rec.emp_val_err := 1;                        -- do not hire the employee
      END IF;

      p_stat := l_stat;


END candidate_duplication_validate;
/*
------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------
--  PROCEDURE shift_validate
--  Author: Christiane Chan
--  Date:  June 02, 2009
--  Parameters:
--  Description: Costa Rica Shift Validation
--
------------------------------------------------------------------------------------------------
*/
PROCEDURE shift_validate (
      p_candidate_id        IN       NUMBER,
      p_shift               IN       VARCHAR2,
      p_prg_flag            IN       VARCHAR2,               --v2.2
      p_stat                OUT      NUMBER,
      --p_stage_rec        IN OUT cust.ttec_taleo_stage%ROWTYPE   --code commented by RXNETHI-ARGANO,17/07/23
      p_stage_rec        IN OUT apps.ttec_taleo_stage%ROWTYPE     --code added by RXNETHI-ARGANO,17/07/23
   )
   IS
      l_shift                 VARCHAR2 (64);
      l_stat                  NUMBER := 0;

BEGIN
      v_module_name := 'Costa Rica SHIFT Validate Routine';

      ttec_taleo_import.print_line (v_module_name);
    IF p_prg_flag = 'Y'
    THEN
        l_stat := 0;
    ELSE
      IF TRIM(p_shift) IS NULL THEN
           l_stat := 1;
      ELSE
         BEGIN

           SELECT b.flex_value
             INTO l_shift
             FROM fnd_flex_value_sets a
                , fnd_flex_values_vl b
            WHERE a.flex_value_set_id = b.flex_value_set_id
              AND a.flex_value_set_name = 'Shift Hours'
              AND b.enabled_flag = 'Y'
              AND b.flex_value = p_shift;

         EXCEPTION
          WHEN OTHERS
          THEN
           -- Shift has an invalid value
            l_stat := 1;
         END;
      END IF;
    END IF;

      IF (l_stat = 1) THEN
         p_stage_rec.emp_val_err := 1;                        -- do not hire the employee
         l_shift                := NULL;
      END IF;

     p_stage_rec.shift           := l_shift;

     p_stat := l_stat;

EXCEPTION
      WHEN OTHERS
      THEN
         l_stat := 2;
         p_stat := l_stat;

END shift_validate;

/*
------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------
--  PROCEDURE person_type_validate
--  Author: Christiane Chan
--  Date:  June 02, 2009
--  Parameters:
--  Description: Costa Rica Person Type Validation
--
--               The only person type currently available in Oracle for Costa Rica is employee
------------------------------------------------------------------------------------------------
*/
PROCEDURE person_type_validate (
      p_candidate_id        IN       NUMBER,
      p_person_type         IN       VARCHAR2,
      p_business_group      IN       VARCHAR2,
      p_stat                OUT      NUMBER,
      --p_stage_rec        IN OUT cust.ttec_taleo_stage%ROWTYPE  --code commented by RXNETHI-ARGANO,17/07/23
      p_stage_rec        IN OUT apps.ttec_taleo_stage%ROWTYPE    --code added by RXNETHI-ARGANO,17/07/23
   )
   IS
      l_person_type           VARCHAR2 (64);
      l_stat                  NUMBER := 0;

BEGIN
      v_module_name := 'Costa Rica Person Type Validate Routine';

      ttec_taleo_import.print_line (v_module_name);


      IF TRIM(p_person_type) IS NULL THEN
                 l_stat := 1;
      ELSE
         BEGIN

           SELECT DISTINCT system_person_type
             INTO l_person_type
             FROM per_person_types
             WHERE business_group_id = p_business_group
             AND person_type_id = p_person_type;
             --AND person_type_id = 553;        -- v2.2

         EXCEPTION
          WHEN OTHERS
          THEN
          -- Person Type has an invalid value
            l_stat := 2;
         END;
      END IF;


      IF (l_stat > 0) THEN
         p_stage_rec.emp_val_err := 1;                        -- do not hire the employee
         l_person_type           := NULL;
      END IF;

     p_stage_rec.person_type     := l_person_type;

     p_stat := l_stat;

EXCEPTION
      WHEN OTHERS
      THEN
         l_stat := 2;
         p_stat := l_stat;

END person_type_validate;
------------------------------------------------------------------------------------------------
/* End Version 1.7 -- Costa Rica Integration */
------------------------------------------------------------------------------------------------
END ttec_taleo_import_CR;
/
show errors;
/