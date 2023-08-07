create or replace PACKAGE      tt_834_vision_service_plan AUTHID CURRENT_USER IS

  ------------------------------------------------------------------------------
  -- Program Name:  APPS.TT_834_VISION_SERVICE_PLAN
  --
  -- Description:
  -- ============
  -- TeleTech ANSI 834 X12 File Formatting Pacakge for Vision Service Plan (VSP).
  -- Data is extracted from Oracle Advanced Benefits for eligible memebrs, formatted per
  -- ANSI 834 X12 specifications and made ready for transmission to VSP via a separte
  -- process on MAPLE.
  --
  -- Dependencies:
  -- =============
  -- PACKAGE SYS.DBMS_UTILITY
  -- PACKAGE SYS.UTL_FILE
  -- PACKAGE APPS.FND_DATE
  -- PACKAGE APPS.TT_LOG
  -- PACKAGE APPS.TT_FILE_METADATA
  -- PACKAGE APPS.TT_834_METADATA
  -- PACKAGE APPS.TT_834_FORAMTTER
  --
  -- Created By:  Fred Sauer, CM Mitchell Consulting (CMMC)
  --
  -- Modification History:
  -- =====================
  --
  -- Date        Modifier           Description
  -- 17/05/23    RXNETHI-ARGANO     R12.2 Upgrade Remediation
  -- ----------  ----------------   ---------------------------------------------
  -- 2006-06-02  Fred Sauer, CMMC   Initial Version
  -- 2006-06-22  Milan Rahman, CMMC Changed the logic to check for Spouse
  --                                and send Employee + Spouse instead of
  --                                Employee + 1
  --                                Full Time Student record is checked to ensure
  --                                that the age is between 19 and 24 inclusive
  --                                and relationship code is not Spouse
  --
  ------------------------------------------------------------------------------

  ------------------------------------------------------------------------------
  -- Package Constants
  ------------------------------------------------------------------------------

  -- Name of this program, used in log output
  c_program_name CONSTANT VARCHAR2(100) := 'Vision Service Plan 834';

  -- Benefit Plan Name
  --c_plan_name_like CONSTANT ben.ben_pl_f.NAME%TYPE := 'Vision Ins';  --code commented by RXNETHI-ARGANO,17/05/23
  c_plan_name_like CONSTANT apps.ben_pl_f.NAME%TYPE := 'Vision Ins';   --code added by RXNETHI-ARGANO,17/05/23

  ------------------------------------------------------------------------------
  -- Convenience Package Types
  ------------------------------------------------------------------------------
  SUBTYPE t_field IS tt_file_metadata.t_field;
  SUBTYPE t_code IS tt_file_metadata.t_code;

  SUBTYPE t_nullability IS tt_file_metadata.t_nullability;
  c_not_null    CONSTANT t_nullability := tt_file_metadata.c_not_null;
  c_null_ok     CONSTANT t_nullability := tt_file_metadata.c_null_ok;
  c_always_null CONSTANT t_nullability := tt_file_metadata.c_always_null;

  SUBTYPE t_charset IS tt_file_metadata.t_charset;
  c_all_chars           CONSTANT t_charset := tt_file_metadata.c_all_chars;
  c_digits_only         CONSTANT t_charset := tt_file_metadata.c_digits_only;
  c_alpha_numeric       CONSTANT t_charset := tt_file_metadata.c_alpha_numeric;
  c_us7ascii            CONSTANT t_charset := tt_file_metadata.c_us7ascii;
  c_ascii_x12n_basic    CONSTANT t_charset := tt_file_metadata.c_ascii_x12n_basic;
  c_ascii_x12n_extended CONSTANT t_charset := tt_file_metadata.c_ascii_x12n_extended;

  SUBTYPE t_collapsability IS tt_file_metadata.t_collapsability;
  c_fixed_length CONSTANT t_collapsability := tt_file_metadata.c_fixed_length;
  c_collapsable  CONSTANT t_collapsability := tt_file_metadata.c_collapsable;

  c_null_text_value CONSTANT t_field := tt_file_metadata.c_null_text_value;
  c_blank           CONSTANT t_field := tt_file_metadata.c_blank;

  ------------------------------------------------------------------------------
  -- Lookup Type where we get our email distribution list
  ------------------------------------------------------------------------------
  c_email_list_lookup_type CONSTANT fnd_lookups.lookup_type%TYPE := 'TT_834_VSP_EMAIL_LIST';

  ------------------------------------------------------------------------------
  -- General Package Constants
  ------------------------------------------------------------------------------

  c_isa05_sender_id_qual        CONSTANT t_field := tt_834_metadata.isa05_30_federal_tax_id;
  c_isa06_sender_id             CONSTANT t_field := tt_834_formatter.c_teletech_tin;
  c_isa07_receiver_id_qual      CONSTANT t_field := tt_834_metadata.isa07_30_federal_tax_id;
  c_isa08_receiver_id           CONSTANT t_field := '94-1632821';
  c_isa11_xchange_control_id    CONSTANT t_field := tt_834_metadata.isa11_u_us_edi_asc_x12;
  c_isa12_xhange_control_verion CONSTANT t_field := tt_834_metadata.isa12_00401;
  c_isa15_usage_indicator       CONSTANT t_field := tt_834_metadata.isa15_t_test;
  c_isa16_component_separator   CONSTANT t_field := '>';
  c_gs02_sender_code            CONSTANT t_field := c_isa06_sender_id;
  c_gs03_receiver_code          CONSTANT t_field := c_isa08_receiver_id;
  c_gs07_resp_agency_code       CONSTANT t_field := tt_834_metadata.gs07_x_accredited_stds_x12;
  c_gs08_version_code           CONSTANT t_field := tt_834_metadata.gs08_004010x095a1;
  c_ref02_master_policy_number  CONSTANT t_field := '4399686';
  c_n102_1000a_plan_name        CONSTANT t_field := 'Vision Ins';
  c_n103_1000a_identifier_code  CONSTANT t_field := tt_834_metadata.n103_1000a_zz_mutually_defined;
  c_n104_1000a_identifier       CONSTANT t_field := tt_834_formatter.c_teletech_tin;
  c_n102_1000b_plan_name        CONSTANT t_field := 'VISION SERVICE PLAN';
  c_n103_1000b_identifier_code  CONSTANT t_field := tt_834_metadata.n103_1000b_fi_federal_tax_id;
  c_n104_1000b_identifier       CONSTANT t_field := c_isa08_receiver_id;
  c_hd03_insurance_line_code    CONSTANT t_field := tt_834_metadata.hd03_vis_vision;
  c_hd05_spouse_cov_level_code  CONSTANT t_field := 'ESP';

  ------------------------------------------------------------------------------
  -- SRS Parameter Constants
  ------------------------------------------------------------------------------

  -- SRS Parameter P_MODE Values
  c_mode_test CONSTANT VARCHAR2(4) := 'TEST';
  c_mode_prod CONSTANT VARCHAR2(4) := 'PROD';

  ------------------------------------------------------------------------------
  -- Create VSP File
  ------------------------------------------------------------------------------
  PROCEDURE generate_file
  (
    p_errbuf                   OUT VARCHAR2,
    p_retcode                  OUT tt_log.t_retcode,
    p_test_prod                IN VARCHAR2,
    p_effective_date           IN VARCHAR2,
    p_initial_output_directory IN VARCHAR2,
    p_initial_output_filename  IN VARCHAR2,
    p_copy_to_directory        IN VARCHAR2,
    p_copy_to_filename         IN VARCHAR2,
    p_log_level_code           IN tt_log.t_log_level_code
  );

END tt_834_vision_service_plan;
/
show errors;
/