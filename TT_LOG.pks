create or replace PACKAGE      tt_log IS

  ------------------------------------------------------------------------------
  -- Program Name:  APPS.TT_LOG
  --
  -- Description:
  -- ============
  -- TeleTech Reusable Logging Pacakge. Provides contextual logging,
  -- the ability to display exception messages within the context of the data
  -- which was being processed at time of the raised exception. Provides
  -- entire stack of PL/SQL program unit names and line numbers where exceptions
  -- were subsequently raised.
  --
  -- Dependencies:
  -- =============
  -- PACKAGE SYS.DBMS_UTILITY
  -- PACKAGE SYS.DBMS_OUTPUT
  -- PACKAGE APPS.FND_GLOBAL
  -- PACKAGE APPS.FND_FILE
  --
  -- Created By:  Fred Sauer, CM Mitchell Consulting (CMMC)
  --
  -- Modification History:
  -- =====================
  --
  -- Date        Modifier          Description
  -- ----------  ----------------  ---------------------------------------------
  -- 2006-06-02  Fred Sauer, CMMC  Initial Version
  -- 2006-08-14  Fred Sauer, CMMC  Additional functionality for TT_COMPSYCH_METADATA
  --                               and TT_COMPSYCH_FORMATTER
  -- 2006-08-16  Fred Sauer, CMMC  Better error message for missing hostname in
  --                               'TT_HOST_NAME_TO_SMTP_MAP' lookup code
  -- 2006-08-21  Fred Sauer, CMMC  Change default time stamp format
  --
  ------------------------------------------------------------------------------

  ------------------------------------------------------------------------------
  -- File and Directory Location Types
  ------------------------------------------------------------------------------

  -- Reusable type for directories and filenames
  SUBTYPE t_file_location IS VARCHAR2(500);

  -- Keep track of our file locations
  TYPE file_location_table IS TABLE OF t_file_location INDEX BY BINARY_INTEGER;

  ------------------------------------------------------------------------------
  -- CUST.TTEC_ERROR_HANDLING Constants
  ------------------------------------------------------------------------------

  c_program_name CONSTANT VARCHAR2(200) := 'TeleTech TT_LOG Logging Package';

  c_ttec_error_status_initial CONSTANT cust.ttec_error_handling.status%TYPE := 'INITIAL';
  c_ttec_error_status_warning CONSTANT cust.ttec_error_handling.status%TYPE := 'WARNING';
  c_ttec_error_status_failure CONSTANT cust.ttec_error_handling.status%TYPE := 'FAILURE';

  ------------------------------------------------------------------------------
  -- Package Profile Options
  ------------------------------------------------------------------------------

  -- Sitename Profile Option
  c_sitename_profile_option CONSTANT fnd_profile_options.profile_option_name%TYPE := 'SITENAME';

  ------------------------------------------------------------------------------
  -- Email Types and Constants
  ------------------------------------------------------------------------------

  c_host_name_smtp_lookup_type CONSTANT fnd_lookup_types.lookup_type%TYPE := 'TT_HOST_NAME_TO_SMTP_MAP';
  c_from_code                  CONSTANT fnd_lookup_values_vl.lookup_code%TYPE := 'FROM';
  c_to_code                    CONSTANT fnd_lookup_values_vl.lookup_code%TYPE := 'TO';
  c_cc_code                    CONSTANT fnd_lookup_values_vl.lookup_code%TYPE := 'CC';
  c_bcc_code                   CONSTANT fnd_lookup_values_vl.lookup_code%TYPE := 'BCC';
  c_notify_success_code        CONSTANT fnd_lookup_values_vl.lookup_code%TYPE := 'NOTIFY_SUCCESS';
  c_notify_warning_code        CONSTANT fnd_lookup_values_vl.lookup_code%TYPE := 'NOTIFY_WARNING';
  c_notify_failure_code        CONSTANT fnd_lookup_values_vl.lookup_code%TYPE := 'NOTIFY_FAILURE';
  c_attach_output_code         CONSTANT fnd_lookup_values_vl.lookup_code%TYPE := 'ATTACH_OUTPUT';
  c_attach_log_code            CONSTANT fnd_lookup_values_vl.lookup_code%TYPE := 'ATTACH_LOG';

  ------------------------------------------------------------------------------
  -- General Package Constants
  ------------------------------------------------------------------------------

  c_utl_file_directory CONSTANT t_file_location := 'ECX_UTL_LOG_DIR_OBJ';

  -- Default or Global Security Group
  c_global_security_group_id fnd_security_groups.security_group_id%TYPE := 0;

  -- default format mask for SHOW_VALUE() with a P_VALUE being a NUMBER
  c_default_number_format_mask CONSTANT VARCHAR2(100) := 'FM999G999G999G999G999G999G999G999G999G990D99999999999999999';

  ------------------------------------------------------------------------------
  -- Concurrent Manager Types and Constants
  ------------------------------------------------------------------------------
  SUBTYPE t_retcode IS BINARY_INTEGER RANGE 0 .. 4;

  c_retcode_success     CONSTANT t_retcode := 0; -- Concurrent Program Status = Normal
  c_retcode_warning     CONSTANT t_retcode := 1; -- Concurrent Program Status = Warning
  c_retcode_failure     CONSTANT t_retcode := 2; -- Concurrent Program Status = Error
  c_retcode_init_failed CONSTANT t_retcode := 3; -- Indicates initialization of this package failed
  c_retcode_invalid     CONSTANT t_retcode := 4; -- Indicates G_RETCODE not yet initialized

  -- Set G_RETCODE to C_RETCODE_SUCCESS at the start of your program
  -- This package will raise the retcode based on the level of logged messages
  -- This package will never lower G_RETCODE
  -- Initial value here is C_RETCODE_INIT_FAILED, but is changed to C_RETCODE_INVALID
  -- after successful package initialize. As stated above, programs using this package
  -- must explicitly set G_RETCODE to C_RETCODE_SUCCESS before using this package.
  g_retcode t_retcode := c_retcode_init_failed;

  ------------------------------------------------------------------------------
  -- Log Level Types and Constants
  --
  -- TRACE  Extremely fine-grained informational events that are most useful to
  --        trace an application
  -- DEBUG  Fine-grained informational events that are most useful to debug
  --        an application
  -- INFO   Informational messages that highlight the progress of the application
  --        at coarse-grained level
  -- WARN   Potentially harmful situations
  -- ERROR  Error events that might still allow the application to continue
  --        running
  -- FATAL  Very severe error events that will presumably lead the application
  --        to abort
  -- OFF    Highest possible rank and is intended to turn off logging
  ------------------------------------------------------------------------------
  SUBTYPE t_log_level IS BINARY_INTEGER RANGE 0 .. 6;
  SUBTYPE t_log_level_code IS VARCHAR2(10);

  -- Please DO NOT use the values 0..6 directory in your code.
  -- Assume that these values are subject to change at any time.
  -- Use the provided constants C_LOG_LEVEL_* instead.
  c_log_level_trace CONSTANT t_log_level := 0;
  c_log_level_debug CONSTANT t_log_level := 1;
  c_log_level_info  CONSTANT t_log_level := 2;
  c_log_level_warn  CONSTANT t_log_level := 3;
  c_log_level_error CONSTANT t_log_level := 4;
  c_log_level_fatal CONSTANT t_log_level := 5;
  c_log_level_off   CONSTANT t_log_level := 6;

  -- Please use the provided constants C_LOG_LEVEL_CODE_* whenever possible.
  -- See the Value Set 'TT_LOG_LEVEL_CODE'.
  c_log_level_code_trace CONSTANT t_log_level_code := 'TRACE';
  c_log_level_code_debug CONSTANT t_log_level_code := 'DEBUG';
  c_log_level_code_info  CONSTANT t_log_level_code := 'INFO';
  c_log_level_code_warn  CONSTANT t_log_level_code := 'WARN';
  c_log_level_code_error CONSTANT t_log_level_code := 'ERROR';
  c_log_level_code_fatal CONSTANT t_log_level_code := 'FATAL';
  c_log_level_code_off   CONSTANT t_log_level_code := 'OFF';

  ------------------------------------------------------------------------------
  -- Individual Log Lines
  ------------------------------------------------------------------------------

  -- Max line length supported by DBMS_OUTPUT in 10g is 32767
  c_dbms_output_max_line_length CONSTANT INTEGER := 32767;

  -- Datatypes for logging
  SUBTYPE t_log_line IS VARCHAR2(32767);
  SUBTYPE t_log_prefix IS VARCHAR2(500);

  ------------------------------------------------------------------------------
  -- Timed Task Types and Constants
  --
  -- Stores pertinent information for named tasks. Allows measurment of elapsed
  -- time and CPU seconds utlizied.
  ------------------------------------------------------------------------------
  TYPE t_task IS RECORD(
    task_name VARCHAR2(200) DEFAULT 'UNINITIALIZED TASK',
    copy_to_output BOOLEAN,
    log_level t_log_level DEFAULT c_log_level_warn,
    start_time_100ths NUMBER,
    end_time_100ths NUMBER,
    start_cpu_time_100ths NUMBER,
    end_cpu_time_100ths NUMBER,
    has_started BOOLEAN DEFAULT FALSE,
    has_finished BOOLEAN DEFAULT FALSE);

  ------------------------------------------------------------------------------
  -- Navigation Path for DFFs and AOL Lookup Types
  ------------------------------------------------------------------------------
  SUBTYPE t_navigation_path IS VARCHAR2(2000);

  ------------------------------------------------------------------------------
  -- Descriptive Flexfields
  --
  -- Stores pertinent information for Descriptive Flexfield definitions.
  ------------------------------------------------------------------------------
  TYPE r_descriptive_flexfield IS RECORD(
    application_short_name fnd_application.application_short_name%TYPE,
    descriptive_flexfield_name fnd_descriptive_flexs_vl.descriptive_flexfield_name%TYPE,
    descriptive_flex_context_code fnd_descr_flex_column_usages.descriptive_flex_context_code%TYPE,
    application_column_name fnd_descr_flex_column_usages.application_column_name%TYPE,
    navigation_path t_navigation_path,
    title fnd_descriptive_flexs_vl.title%TYPE,
    end_user_column_name fnd_descr_flex_column_usages.end_user_column_name%TYPE);

  ------------------------------------------------------------------------------
  -- Application Object Library Lookup Type
  --
  -- Stores pertinent information for AOL Lookup Type.
  ------------------------------------------------------------------------------
  TYPE r_aol_lookup_type IS RECORD(
    initialized BOOLEAN DEFAULT FALSE,
    application_id fnd_application.application_id%TYPE,
    application_short_name fnd_application.application_short_name%TYPE,
    view_application_id fnd_application.application_id%TYPE,
    view_application_short_name fnd_application.application_short_name%TYPE,
    lookup_type fnd_lookup_types_vl.lookup_type%TYPE,
    description fnd_lookup_types_vl.description%TYPE,
    navigation_path t_navigation_path);

  ------------------------------------------------------------------------------
  -- Application Object Library Lookup Value
  --
  -- Stores pertinent information for AOL Lookup Value.
  ------------------------------------------------------------------------------
  TYPE r_aol_lookup_value IS RECORD(
    aol_lookup_type r_aol_lookup_type,
    lookup_code fnd_lookup_values_vl.lookup_code%TYPE,
    meaning fnd_lookup_values_vl.meaning%TYPE,
    description fnd_lookup_values_vl.description%TYPE);

  ------------------------------------------------------------------------------
  -- Determine Calling Code Package Name and Line Number
  --
  -- Used internally for contextual logging. Also available to other packages.
  -- Parses DBMS_UTILITY.FORMAT_CALL_STACK to determine calling PL/SQL program
  -- unit (name) and line number.
  --
  -- Parameters:
  -- ===========
  --
  -- P_ADDITIONAL_DEPTH
  --     When calling this procedure directly from you code, use the default 0.
  --     When calling your logging procedure which in turn calls this procedure,
  --     use 1 to have this procedure go one level deeper into the stack trace
  --     to get the correct line number in your calling PL/SQL Block.

  ------------------------------------------------------------------------------
  FUNCTION determine_caller(p_additional_depth IN NUMBER DEFAULT 0) RETURN VARCHAR2;

  ------------------------------------------------------------------------------
  -- Set wrap line length
  --
  -- Set line length at which to wrap output to DMBS_OUTPUT. This is useful when
  -- using this package interactively within a SQL*Plus or terminal window.
  --
  -- Parameters:
  -- ===========
  --
  -- P_WRAP_LINE_LENGTH
  --     Maximum line length to be printed. Lines are wrapped as needed.
  --
  ------------------------------------------------------------------------------
  PROCEDURE set_dbms_output_wrap_length(p_wrap_line_length IN INTEGER);

  ------------------------------------------------------------------------------
  -- Quote, escape or DUMP() value as needed
  --
  -- Overloaded function used anywhere when a value must be output to a log or
  -- otherwise displayed to an end user. Text is surrounded by quotes. Numbers
  -- (except for very large number) are formatted with commas and decimals for
  -- readability. Dates are shown with complete date/time components. NULLs are
  -- replaced by P_ALTERNATE_TEXT_WHEN_NULL.
  --
  -- Parameters:
  -- ===========
  --
  -- P_VALUE
  --     Raw value to be displayed to end user.
  --
  -- P_ALTERNATE_TEXT_WHEN_NULL
  --     Text to display if P_VALUE IS NULL. Default text is 'NULL'.
  --
  -- P_FORMAT_MASK
  --     (Applies to P_VALUE is NUMBER only)
  --     Default value provides for thousand's and decimal delimiters, and
  --     trims any zeros (and if needed the decimal itself) from the decimals.
  --     Set to NULL if no formatting is desired, e.g. when displaying an ID
  --     column value.
  --
  ------------------------------------------------------------------------------
  FUNCTION show_value
  (
    p_value IN VARCHAR2,
    p_alternate_text_when_null IN VARCHAR2 DEFAULT 'NULL'
  ) RETURN VARCHAR2;

  FUNCTION show_value
  (
    p_value IN DATE,
    p_alternate_text_when_null IN VARCHAR2 DEFAULT 'NULL'
  ) RETURN VARCHAR2;

  FUNCTION show_value
  (
    p_value IN NUMBER,
    p_alternate_text_when_null IN VARCHAR2 DEFAULT 'NULL',
    p_format_mask IN VARCHAR2 DEFAULT c_default_number_format_mask
  ) RETURN VARCHAR2;

  FUNCTION show_value
  (
    p_value IN BOOLEAN,
    p_alternate_text_when_null IN VARCHAR2 DEFAULT 'NULL'
  ) RETURN VARCHAR2;

  FUNCTION show_value
  (
    p_value IN INTERVAL DAY TO SECOND,
    p_alternate_text_when_null IN VARCHAR2 DEFAULT 'NULL'
  ) RETURN VARCHAR2;

  ------------------------------------------------------------------------------
  -- Display id column value or 'NULL'
  --
  -- Equivalent to calling SHOW_VALUE() with P_FORMAT_MASK = NULL
  --
  -- Parameters:
  -- ===========
  --
  -- P_VALUE
  --     Raw value to be displayed to end user.
  --
  -- P_ALTERNATE_TEXT_WHEN_NULL
  --     Text to display if P_VALUE IS NULL. Default text is 'NULL'.
  --
  ------------------------------------------------------------------------------
  FUNCTION show_id
  (
    p_value IN NUMBER,
    p_alternate_text_when_null IN VARCHAR2 DEFAULT 'NULL'
  ) RETURN VARCHAR2;

  ------------------------------------------------------------------------------
  -- Log Message to current "out" destination(s)
  --
  -- Message is output to APPS.FND_FILE.OUT or DBMS_OUTPUT, with some formatting
  -- such as line breaks. A timestamp is not included.
  --
  -- Parameters:
  -- ===========
  --
  -- P_MESSAGE
  --     The text message you wish to send to the output.
  --
  -- P_ADDITIONAL_DEPTH
  --     See DETERMINE_CALLER().
  --
  ------------------------------------------------------------------------------
  PROCEDURE output
  (
    p_message IN t_log_line,
    p_additional_depth IN NUMBER DEFAULT 0
  );

  ------------------------------------------------------------------------------
  -- Error Message to "out" destination(s)
  --
  -- Message is output to APPS.FND_FILE.OUT or DBMS_OUTPUT, with some formatting
  -- such as line breaks. A timestamp is not included.
  -- The displayed message will include the error code, error message and the
  -- value of P_MESSAGE in the output.
  --
  -- Side effect: Raises G_RETCODE to C_RETCODE_FAILURE.
  --
  -- Parameters:
  -- ===========
  --
  -- P_SQLCODE
  --     Set to SQLCODE
  --
  -- P_SQLERRM
  --     Set to SQLERRM
  --
  -- P_MESSAGE
  --     The text message you wish to send to the log file.
  --
  ------------------------------------------------------------------------------
  PROCEDURE output_error
  (
    p_sqlcode IN NUMBER,
    p_sqlerrm IN VARCHAR2,
    p_message IN t_log_line
  );

  ------------------------------------------------------------------------------
  -- Log Message to current "log" destination(s)
  --
  -- Message is output to APPS.FND_FILE.LOG or DBMS_OUTPUT, including a timestamp
  -- and other standard formatting. Line breaks are also handled, prefixing the
  -- first and all subsequent lines.
  --
  -- Side effect: Raises G_RETCODE to C_RETCODE_WARNING for log level C_LOG_WARN.
  -- Side effect: Raises G_RETCODE to C_RETCODE_FAILURE for log levels C_LOG_ERROR,
  --              and C_LOG_LEVEL_FATAL.
  --
  -- Parameters:
  -- ===========
  --
  -- P_LOG_LEVEL
  --     The detail level of the message you are currently trying to log. Message
  --     will be suppressed if the current log level (G_LOG_LEVEL) is higher than
  --     this value.
  --
  -- P_MESSAGE
  --     The text message you wish to send to the log file.
  --
  -- P_COPY_TO_OUTPUT
  --     Set to TRUE if you also want to send this message to the output.
  --
  -- P_ADDITIONAL_DEPTH
  --     See DETERMINE_CALLER().
  --
  ------------------------------------------------------------------------------
  PROCEDURE log
  (
    p_log_level IN t_log_level,
    p_message IN t_log_line,
    p_copy_to_output IN BOOLEAN DEFAULT FALSE,
    p_additional_depth IN NUMBER DEFAULT 0
  );

  ------------------------------------------------------------------------------
  -- Log TRACE Message
  --
  -- Equivalent to calling LOG() with P_LOG_LEVEL = C_LOG_LEVEL_TRACE
  --
  -- Parameters:
  -- ===========
  --     See LOG().
  --
  -- Examples:
  -- =========
  -- For simple message logging write:
  --
  --   TT_LOG.DEBUG('simple debugging message');
  --
  --   TT_LOG.INFO('simple informational message');
  --
  --   TT_LOG.ERROR('simple error message'); -- note: will cause concurrent program to error
  --
  -- When the creation or formatting of the message to be logged would have a
  -- noticably impact on performance, you can avoid most of the overhead when
  -- trace and/or debug level logging is turned off by using a conditional test
  -- to prevent the PL/SQL code inside the IF statement from being evaluated
  -- at runtime:
  --
  --   IF TT_LOG.TRACE_ENABLED THEN
  --     TT_LOG.TRACE('complex message'||EXPENSIVE_FUNCTION_HERE()||'...');
  --   END IF;
  --
  --   IF TT_LOG.DEBUG_ENABLED THEN
  --     TT_LOG.DEBUG('complex message'||EXPENSIVE_FUNCTION_HERE()||'...');
  --   END IF;
  --
  -- In certain cases you may wish to execute additional PL/SQL code when
  -- trace or debug level logging is turned on:
  --
  --   IF TT_LOG.DEBUG_ENABLED THEN
  --     ...
  --     ...
  --     TT_LOG.DEBUG('...');
  --     ...
  --   END IF;
  ------------------------------------------------------------------------------
  PROCEDURE trace
  (
    p_message IN t_log_line,
    p_copy_to_output IN BOOLEAN DEFAULT FALSE,
    p_additional_depth IN NUMBER DEFAULT 0
  );

  ------------------------------------------------------------------------------
  -- Log DEBUG Message
  --
  -- Covenience procedure, for logging DEBUG messages. Equivalent to calling
  -- LOG() with P_LOG_LEVEL = C_LOG_LEVEL_DEBUG.
  --
  -- Parameters:
  -- ===========
  --     See LOG().
  --
  ------------------------------------------------------------------------------
  PROCEDURE debug
  (
    p_message IN t_log_line,
    p_copy_to_output IN BOOLEAN DEFAULT FALSE,
    p_additional_depth IN NUMBER DEFAULT 0
  );

  ------------------------------------------------------------------------------
  -- Log INFO Message
  --
  -- Covenience procedure, for logging INFO messages. Equivalent to calling
  -- LOG() with P_LOG_LEVEL = C_LOG_LEVEL_INFO.
  --
  --
  -- Parameters:
  -- ===========
  --     See LOG().
  --
  ------------------------------------------------------------------------------
  PROCEDURE info
  (
    p_message IN t_log_line,
    p_copy_to_output IN BOOLEAN DEFAULT FALSE,
    p_additional_depth IN NUMBER DEFAULT 0
  );

  ------------------------------------------------------------------------------
  -- Log WARN Message
  --
  -- Covenience procedure, for logging WARN messages. Equivalent to calling
  -- LOG() with P_LOG_LEVEL = C_LOG_LEVEL_WARN.
  --
  -- Side effect: Raises G_RETCODE to C_RETCODE_WARNING.
  --
  -- Parameters:
  -- ===========
  --     See LOG().
  --
  ------------------------------------------------------------------------------
  PROCEDURE warn
  (
    p_message IN t_log_line,
    p_copy_to_output IN BOOLEAN DEFAULT FALSE,
    p_additional_depth IN NUMBER DEFAULT 0
  );

  ------------------------------------------------------------------------------
  -- Log ERROR Message
  --
  -- Covenience procedure, for logging ERROR messages. Equivalent to calling
  -- LOG() with P_LOG_LEVEL = C_LOG_LEVEL_ERROR.
  --
  -- Side effect: Raises G_RETCODE to C_RETCODE_FAILURE.
  --
  -- Parameters:
  -- ===========
  --     See LOG().
  --
  -- Examples:
  -- =========
  -- In general just write:
  --
  --   TT_LOG.ERROR('message');
  --
  -- Since the log level is unlikely to be raised above C_LOG_LEVEL_ERROR to
  -- suppress ERROR messages, and since ERROR messages are expected to be rare,
  -- there is not much point to:
  --
  --   IF TT_LOG.ERROR_ENABLED THEN
  --     TT_LOG.ERROR('message');
  --   END IF;
  --
  ------------------------------------------------------------------------------
  PROCEDURE error
  (
    p_message IN t_log_line,
    p_copy_to_output IN BOOLEAN DEFAULT FALSE,
    p_additional_depth IN NUMBER DEFAULT 0
  );

  ------------------------------------------------------------------------------
  -- Log FATAL Message
  --
  -- Covenience procedure, for logging FATAL messages. Equivalent to calling
  -- LOG() with P_LOG_LEVEL = C_LOG_LEVEL_FATAL.
  --
  -- Side effect: Raises G_RETCODE to C_RETCODE_FAILURE.
  --
  -- Parameters:
  -- ===========
  --     See LOG().
  --
  -- Examples:
  -- =========
  -- In general just write:
  --
  --   TT_LOG.FATAL('message');
  --
  -- Since the log level is unlikely to be raised above C_LOG_LEVEL_FATAL to
  -- suppress FATAL messages, and since FATAL messages are expected to be rare,
  -- there is not much point to:
  --
  --   IF TT_LOG.FATAL_ENABLED THEN
  --     TT_LOG.FATAL('message');
  --   END IF;
  --
  ------------------------------------------------------------------------------
  PROCEDURE fatal
  (
    p_message IN t_log_line,
    p_copy_to_output IN BOOLEAN DEFAULT FALSE,
    p_additional_depth IN NUMBER DEFAULT 0
  );

  ------------------------------------------------------------------------------
  -- Set Current Log Level
  --
  -- Parameters:
  -- ===========
  --
  -- P_LOG_LEVEL
  --     Desired log level.
  --
  -- Please use the provided C_LOG_LEVEL_* constants.
  ------------------------------------------------------------------------------
  PROCEDURE set_log_level(p_log_level IN t_log_level);

  ------------------------------------------------------------------------------
  -- Set Log Level based on code
  --
  -- Useful when the log level code is part of an SRS parameter.
  -- Please use the provided C_LOG_LEVEL_CODE_* constants.
  -- You may use the Value Set 'TT_LOG_LEVEL_CODE'.
  --
  -- Parameters:
  -- ===========
  --
  -- P_LOG_LEVEL_code
  --     Desired log level code.
  --
  ------------------------------------------------------------------------------
  PROCEDURE set_log_level(p_log_level_code IN t_log_level_code);

  ------------------------------------------------------------------------------
  -- Get Current Log Level
  --
  -- Return the current log level. Can be compared to C_LOG_LEVEL_* constants.
  ------------------------------------------------------------------------------
  FUNCTION get_log_level RETURN t_log_level;

  ------------------------------------------------------------------------------
  -- Are TRACE messages currently being logged?
  --
  -- Used in IF statement predicate to avoid time consuming evaluations when
  -- logging at this level is turned off.
  --
  -- Examples:
  -- =========
  --   See TRACE().
  ------------------------------------------------------------------------------
  FUNCTION trace_enabled RETURN BOOLEAN;

  ------------------------------------------------------------------------------
  -- Are DEBUG messages currently being logged?
  --
  -- Used in IF statement predicate to avoid time consuming evaluations when
  -- logging at this level is turned off.
  --
  -- Examples:
  -- =========
  --   See DEBUG().
  ------------------------------------------------------------------------------
  FUNCTION debug_enabled RETURN BOOLEAN;

  ------------------------------------------------------------------------------
  -- Are INFO messages currently being logged?
  --
  -- Used in IF statement predicate to avoid time consuming evaluations when
  -- logging at this level is turned off.
  --
  -- Examples:
  -- =========
  --   See INFO().
  ------------------------------------------------------------------------------
  FUNCTION info_enabled RETURN BOOLEAN;

  ------------------------------------------------------------------------------
  -- Are WARN messages currently being logged?
  --
  -- Used in IF statement predicate to avoid time consuming evaluations when
  -- logging at this level is turned off.
  --
  -- Examples:
  -- =========
  --   See WARN().
  ------------------------------------------------------------------------------
  FUNCTION warn_enabled RETURN BOOLEAN;

  ------------------------------------------------------------------------------
  -- Are ERROR messages currently being logged?
  --
  -- Used in IF statement predicate to avoid time consuming evaluations when
  -- logging at this level is turned off.
  --
  -- Examples:
  -- =========
  --   See ERROR().
  ------------------------------------------------------------------------------
  FUNCTION error_enabled RETURN BOOLEAN;

  ------------------------------------------------------------------------------
  -- Are FATAL messages currently being logged?
  --
  -- Used in IF statement predicate to avoid time consuming evaluations when
  -- logging at this level is turned off.
  --
  -- Examples:
  -- =========
  --   See FATAL().
  ------------------------------------------------------------------------------
  FUNCTION fatal_enabled RETURN BOOLEAN;

  ------------------------------------------------------------------------------
  -- Raise Contextual Exception
  --
  -- Most commonly this procedure can be used to raise what we call here a
  -- 'contextual exception' from any EXCEPTION block, in order to propagate
  -- the original exception back to the original calling PL/SQL block, along
  -- with additional context information (a phrase, some variable values,
  -- a point of reference, etc.).
  --
  -- This procedure may also be called from any normal (non-EXCEPTION) block
  -- to raise what we call here a 'user exception'.
  --
  -- In each calling PL/SQL block, add an EXCEPTION block and again call
  -- RAISE_CONTEXTUAL_EXCEPTION().
  --
  -- In the outer most PL/SQL block you must call LOG_CONTEXTUAL_EXCEPTION()
  -- instead of RAISE_CONTEXTUAL_EXCEPTION to log the entire context stack
  -- thus collected.
  --
  -- Parameters:
  -- ===========
  --
  -- P_SQLCODE
  --     Set to SQLCODE.
  --
  -- P_SQLERRM
  --     Set to SQLERRM.
  --
  -- P_BACKTRACE
  --     Set to DBMS_UTILITY.FORMAT_ERROR_BACKTRACE. This produces a formatted
  --     call stack which begin with the PL/SQL code and line number in which
  --     DBMS_UTILITY.FORMAT_ERROR_BACKTRACE is called.
  --
  -- P_CONTEXT
  --     Provide any additional context information that would be useful in
  --     debugging or tracking down the source of the original exception. You can
  --     include the variables of a cursor, a brief description of what step
  --     was being performed when the exception was raised, etc.
  --
  -- Examples:
  -- =========
  --
  --   PROCEDURE PROC_A IS
  --   BEGIN
  --     ...
  --   EXCEPTION WHEN OTHERS THEN
  --     RAISE_CONTEXTUAL_EXCEPTION(p_sqlcode   => SQLCODE,
  --                                p_sqlerrm   => SQLERRM,
  --                                p_backtrace => DBMS_UTILITY.FORMAT_ERROR_BACKTRACE,
  --                                p_context   => 'in PROC_A');
  --   END;
  --
  --   PROCEDURE PROC_B IS
  --   BEGIN
  --     PROC_A;
  --   EXCEPTION WHEN OTHERS THEN
  --     LOG_CONTEXTUAL_EXCEPTION(p_sqlcode   => SQLCODE,
  --                              p_sqlerrm   => SQLERRM,
  --                              p_backtrace => DBMS_UTILITY.FORMAT_ERROR_BACKTRACE,
  --                              p_context   => 'Executing PROC_B');
  --   END;
  --
  -- Sample Output:
  -- ==============
  --
  --   See LOG_CONTEXTUAL_EXCEPTION().
  --
  ------------------------------------------------------------------------------
  PROCEDURE raise_contextual_exception
  (
    p_sqlcode IN NUMBER,
    p_sqlerrm IN VARCHAR2,
    p_backtrace IN t_log_line,
    p_context IN t_log_line
  );

  ------------------------------------------------------------------------------
  -- Log Contextual Exception
  --
  -- If an exception is caught in the outer most calling PL/SQL block, or
  -- in any other location where it is not desirable to reraise an exception,
  -- this procedure can be used to log the exception, including the detail
  -- of any other raise_contextual_exception() calls that were made since the
  -- original exception being raised.
  -- Use P_LOG_LEVEL to indicate what level of failure this exception is considered to be.
  -- Note: This procedure does not reraise an exception like
  -- RAISE_CONTEXTUAL_EXCEPTION() does.
  --
  -- Parameters:
  -- ===========
  --
  -- P_LOG_LEVEL
  --     The detail level of the log stack messages you are currently trying to log.
  --     The output of this procedure will be suppressed if the current log level
  --     (G_LOG_LEVEL) is higher than this value.
  --
  -- P_SQLCODE
  --     Set to SQLCODE.
  --
  -- P_SQLERRM
  --     Set to SQLERRM.
  --
  -- P_BACKTRACE
  --     See RAISE_CONTEXTUAL_EXCEPTION().
  --
  -- P_CONTEXT
  --     See RAISE_CONTEXTUAL_EXCEPTION().
  --
  --
  -- Examples:
  -- =========
  --
  --   LOG_CONTEXTUAL_EXCEPTION(p_log_level => TT_LOG.LOG_LEVEL_FATAL,
  --                            p_sqlcode   => SQLCODE,
  --                            p_sqlerrm   => SQLERRM,
  --                            p_backtrace => DBMS_UTILITY.FORMAT_ERROR_BACKTRACE,
  --                            p_context   => 'in PROC_A');
  --
  -- Sample Output:
  -- ==============
  --
  -- 2006/05/12 13:38:35.60 [APPS.TT_834_DELTA_DENTAL:284] CONTEXTUAL EXCEPTION RAISED
  --   (1) at [APPS.TT_FILE_METADATA:146] ORA-20999: Assertion (field REF02 IS NOT NULL) failed!
  --   (2) at [APPS.TT_FILE_METADATA:181] checking common assertions
  --   (3) at [APPS.TT_FILE_METADATA:687] formatting text field
  --   (4) at [APPS.TT_FILE_METADATA:788] formatting p_value = NULL with
  --                                      FIELD DEFINITION:
  --                                      - field_name = 'REF02'
  --                                      - field_type = TEXT
  --                                      - min length = 1
  --                                      - max length = 30
  --                                      - NOT NULL
  --                                      - ALL CHARACTERS ALLOWED
  --                                      - COLLAPSABLE
  --                                      - description = 'Reference Identification'
  --   (5) at [APPS.TT_834_FORMATTER:181] in Loop 2000 (Member Level Detail)
  --   (6) at [APPS.TT_834_FORMATTER:286] while processing member number 8, Michael Baker (person_id = 1080)
  --   (7) at [APPS.TT_834_DELTA_DENTAL:284] during file generation
  ------------------------------------------------------------------------------
  PROCEDURE log_contextual_exception
  (
    p_log_level IN t_log_level,
    p_sqlcode IN NUMBER,
    p_sqlerrm IN VARCHAR2,
    p_backtrace IN t_log_line,
    p_context IN t_log_line
  );

  ------------------------------------------------------------------------------
  -- Lookup Security Group Name
  --
  -- Parameters:
  -- ===========
  --
  -- P_SECURITY_GROUP_ID
  --     The SECURITY_GROUP_ID to lookup, often from FND_GLOBAL.SECURITY_GROUP_ID.
  --
  ------------------------------------------------------------------------------
  FUNCTION get_security_group_name(p_security_group_id IN NUMBER) RETURN VARCHAR2;

  ------------------------------------------------------------------------------
  -- Lookup Business Group Name
  --
  -- Parameters:
  -- ===========
  --
  -- P_BUSINESS_GROUP_ID
  --     The BUSINESS_GROUP_ID to lookup, often from the BUSINESS_GROUP_ID
  --     Profile Option.
  --
  ------------------------------------------------------------------------------
  FUNCTION get_business_group_name(p_business_group_id IN NUMBER) RETURN VARCHAR2;

  ------------------------------------------------------------------------------
  -- Describe Descriptive Flexfield
  --
  -- Provide a description of the DFF for inclusion in a log or output file.
  --
  -- Parameters:
  -- ===========
  --
  -- P_DESCRIPTIVE_FLEXFIELD
  --     The DFF definition to describe.
  --
  ------------------------------------------------------------------------------
  FUNCTION describe_descriptive_flexfield(p_descriptive_flexfield IN r_descriptive_flexfield) RETURN VARCHAR2;

  ------------------------------------------------------------------------------
  -- Get Descriptive Flexfield
  --
  -- Lookup a DFF definition.
  --
  -- Parameters:
  -- ===========
  --
  -- P_APPLICAION_SHORT_NAME
  --     The APPLICATION_SHORT_NAME from FND_APPLICATION.
  --
  -- P_DESCIPTIVE_FLEXFIELD_NAME
  --     The DESCRIPTIVE_FLEXFIELD_NAME from FND_DESCRIPTIVE_FLEXS_VL.
  --
  -- P_DESCIPTIVE_FLEX_CTX_CODE
  --     The DESCIPTIVE_FLEX_CTX_CODE from FND_DESCR_FLEX_COLUMN_USAGES.
  --
  -- P_APPLICATION_COLUMN_NAME
  --     The APPLICATION_COLUMN_NAME from FND_DESCR_FLEX_COLUMN_USAGES.
  --
  -- P_NAVIGATION_PATH
  --     The navigation path a user can use to access this DFF.
  --     Used in log file messages.
  --
  ------------------------------------------------------------------------------
  FUNCTION get_descriptive_flexfield
  (
    p_application_short_name IN fnd_application.application_short_name%TYPE,
    p_descriptive_flexfield_name IN fnd_descriptive_flexs_vl.descriptive_flexfield_name%TYPE,
    p_descriptive_flex_ctx_code IN fnd_descr_flex_column_usages.descriptive_flex_context_code%TYPE DEFAULT 'Global Data Elements',
    p_application_column_name IN fnd_descr_flex_column_usages.application_column_name%TYPE,
    p_navigation_path IN t_navigation_path
  ) RETURN r_descriptive_flexfield;

  ------------------------------------------------------------------------------
  -- Describe Application Object Library Lookup Type
  --
  -- Provide a description of the AOL Lookup Type for inclusion in a log or
  -- output file.
  --
  -- Parameters:
  -- ===========
  --
  -- P_AOL_LOOKUP_TYPE
  --     The AOL Lookup Type to describe.
  --
  ------------------------------------------------------------------------------
  FUNCTION describe_aol_lookup_type(p_aol_lookup_type IN r_aol_lookup_type) RETURN VARCHAR2;

  ------------------------------------------------------------------------------
  -- Get Application Object Library Lookup Type
  --
  -- Lookup an AOL Lookup Type.
  --
  -- Parameters:
  -- ===========
  --
  -- P_APPLICATION_SHORT_NAME
  --     The APPLICATION_SHORT_NAME from FND_APPLICATION.
  --
  -- P_VIEW_APPLICATION_SHORT_NAME
  --     The APPLICATION_SHORT_NAME from FND_APPLICATION.
  --
  -- P_LOOKUP_TYPE
  --     The LOOKUP_TYPE from FND_LOOKUP_TYPES_VL
  --
  -- P_NAVIGATION_PATH
  --     The navigation path to be displayed to the user in log/out files.
  --
  ------------------------------------------------------------------------------
  FUNCTION get_aol_lookup_type
  (
    p_application_short_name IN fnd_application.application_short_name%TYPE DEFAULT 'CUST',
    p_view_application_short_name IN fnd_application.application_short_name%TYPE DEFAULT 'FND',
    p_lookup_type IN fnd_lookup_types_vl.lookup_type%TYPE,
    p_navigation_path IN t_navigation_path
  ) RETURN r_aol_lookup_type;

  ------------------------------------------------------------------------------
  -- Get Application Object Library Lookup Value
  --
  -- Lookup an AOL Lookup Value.
  --
  -- Parameters:
  -- ===========
  --
  -- P_AOL_LOOKUP_TYPE
  --     The Lookup Type where the desired Lookup Code can be found.
  --
  -- P_LOOKUP_CODE
  --     The LOOKUP_CODE which is to be selected.
  --
  ------------------------------------------------------------------------------
  FUNCTION get_aol_lookup_value
  (
    p_aol_lookup_type IN r_aol_lookup_type,
    p_lookup_code IN fnd_lookup_values_vl.lookup_code%TYPE
  ) RETURN r_aol_lookup_value;

  ------------------------------------------------------------------------------
  -- Assert Condition
  --
  -- Assert that a given condition is TRUE. If it is, this procedure will
  -- return normally and log nothing. If the condition is not true, then
  -- an exception is raised, including a human readable form of the condition
  -- which was being asserted, and optionally additional context information
  -- for the log message.
  -- If P_FAILURE_OUTPUT_MESSAGE is provided, it will be sent to the "out"
  -- destination(s) upon failure.
  --
  -- Parameters:
  -- ===========
  --
  -- P_CONDITION
  --     The boolean predicate which is expected to evaluate to TRUE.
  --
  -- P_CONDITION_TEXT
  --     The human textual representation of the above condition.
  --
  -- P_NEG_CONDITION_TEXT
  --     The human textual representation of the oposite (negative) of
  --     the above condition.
  --
  -- P_CONTEXT
  --     See RAISE_CONTEXTUAL_EXCEPTION().
  --
  -- P_COPY_TO_OUTPUT
  --     See LOG().
  --
  --
  -- Examples:
  -- =========
  --
  --   ASSERT(p_condition      => emp.sal <= 10000,
  --          p_neg_condition_text => 'Salary above $10,000',
  --          p_context        => 'while processing employee with id '||emp.id);
  --
  -- Sample Output:
  -- ==============
  --
  -- 2006/05/12 13:38:35.60 [APPS.TT_SAMPLE:284] CONTEXTUAL EXCEPTION RAISED
  --   (1) at [APPS.TT_SAMPLE:146] ORA-20999: Salary above $10,000
  --   (2) at [APPS.TT_SAMPLE:181] while processing employee with id 12345
  --   (3) at [APPS.TT_SAMPLE:687] ...
  --   (4) at [APPS.TT_SAMPLE:788] ...
  ------------------------------------------------------------------------------
  PROCEDURE assert
  (
    p_condition IN BOOLEAN,
    p_condition_text IN VARCHAR2 DEFAULT NULL,
    p_neg_condition_text IN VARCHAR2 DEFAULT NULL,
    p_context IN t_log_line DEFAULT NULL,
    p_copy_to_output IN BOOLEAN DEFAULT FALSE
  );

  ------------------------------------------------------------------------------
  -- Map a logical directory component (from DBA_DIRECTORIES) of a filename to
  -- its physical location, or return the original location if such a mapping
  -- cannot be preformed
  ------------------------------------------------------------------------------
  FUNCTION filename_logical_to_physical(p_directory_and_filename IN t_file_location) RETURN VARCHAR2;

  ------------------------------------------------------------------------------
  -- Email Completion Status
  --
  -- Email a success or failure message to recipients, depening on whether this
  -- procedure is called from an exception block or not.
  -- The Stored Procedure SEND_EMAIL() is used to actually deliver the email.
  --
  -- Parameters:
  -- ===========
  --
  -- P_SQLCODE
  --     Set to SQLCODE.
  --
  -- P_SQLERRM
  --     Set to SQLERRM.
  --
  -- P_PROGRAM_NAME
  --     Name of your program for inclusion in the log file.
  --
  -- P_COPY_MESSAGES_TO_OUTPUT
  --     If TRUE, log messages are also sent to output.
  --
  -- P_EMAIL_AOL_LOOKUP_TYPE
  --     Short name of Application Object Library Lookup Type which contains
  --     the email configuration to be used.
  --     * Specifies FROM, TO, CC, BCC addreses
  --     * Specifies if LOG and/or OUT files are to be attached.
  --     * Specifies if an email is to be sent upon SUCCESS, WARNING and/or FAILURE.
  --
  -- P_MESSAGE
  --     Optional message to include in email.
  --
  -- P_ATTACHMENT1
  --     Fully qualified filename of additional attachment.
  --
  -- P_ATTACHMENT2
  --     Fully qualified filename of additional attachment.
  --
  -- P_ATTACHMENT3
  --     Fully qualified filename of additional attachment.
  --
  ------------------------------------------------------------------------------
  PROCEDURE email_completion_status
  (
    p_sqlcode IN NUMBER,
    p_sqlerrm IN VARCHAR2,
    p_program_name IN VARCHAR2,
    p_copy_messages_to_output IN BOOLEAN,
    p_email_aol_lookup_type IN r_aol_lookup_type,
    p_message IN VARCHAR2 DEFAULT NULL,
    p_attachment1 IN VARCHAR2 DEFAULT NULL,
    p_attachment2 IN VARCHAR2 DEFAULT NULL,
    p_attachment3 IN VARCHAR2 DEFAULT NULL
  );

  ------------------------------------------------------------------------------
  -- Set Concurrent Manager Return Values
  --
  -- Sets the Concurrent Manager return values, P_ERRBUF and P_RETCODE.
  -- The values set are based on:
  -- * The value of P_SQLCODE; determines if this procedure was called
  --   from an EXCEPTION block or not.
  -- * Whether any messages have been logged at a level of C_LOG_LEVEL_WARN,
  --   C_LOG_LEVEL_ERROR or C_LOG_LEVEL_FATAL.
  --
  -- Call this PROCEDURE at the successful completion of your concurrent program,
  -- and in the EXCEPTION block of your concurrent program.
  --
  -- Parameters:
  -- ===========
  --
  -- P_SQLCODE
  --     Set to SQLCODE.
  --
  -- P_SQLERRM
  --     Set to SQLERRM.
  --
  -- P_PROGRAM_NAME
  --     Name of your program for inclusion in the log file and completion message.
  --
  -- P_ERRBUF
  --     The reference to the first parameter of your PL/SQL procedure. This is used
  --     by the Concurrent Manager to return the completion message which is displayed
  --     in the Concurrent Manager log file and in the Details screen.
  --
  -- P_RETCODE
  --     The reference to the second parameter of your PL/SQL procedure. This is used
  --     by the Concurrent Manager to return the completion status of the concurrent
  --     program: Normal, Warning, Failure.
  --
  ------------------------------------------------------------------------------
  PROCEDURE set_conc_manager_return_values
  (
    p_sqlcode IN NUMBER,
    p_sqlerrm IN VARCHAR2,
    p_program_name IN VARCHAR2,
    p_errbuf OUT VARCHAR2,
    p_retcode OUT t_retcode
  );

  ------------------------------------------------------------------------------
  -- Log Elapsed Time
  --
  -- Log elapsed time and CPU usage for task given task.
  --
  -- Parameters:
  -- ===========
  --
  -- P_TASK
  --     The task for which elapsed time is to be logged.
  --
  -- P_ADDITIONAL_DEPTH
  --     See DETERMINE_CALLER().
  --
  ------------------------------------------------------------------------------
  PROCEDURE log_elapsed_time
  (
    p_task IN t_task,
    p_additional_depth IN NUMBER DEFAULT 0
  );

  ------------------------------------------------------------------------------
  -- Start a new Timed Task
  --
  -- Automatic logging of elapsed time and CPU usage for any PL/SQL block.
  --
  -- Parameters:
  -- ===========
  --
  -- P_LOG_LEVEL
  --     See LOG().
  --
  -- P_TASK_NAME
  --     The name to be assigned to this task for use in logging.
  --
  -- P_COPY_TO_OUTPUT
  --     See LOG().
  --
  -- P_ADDITIONAL_DEPTH
  --     See DETERMINE_CALLER().
  --
  -- Sample Output:
  -- ==============
  --
  --   2006/05/19 13:24:20.01 [INFO][APPS.TT_TEST:134][My Program] <My Task> STARTED
  --   ...
  --   2006/05/19 13:24:21.92 [INFO][APPS.TT_TEST:884][My Program] <My Task> has taken 5 minutes, 0.12 seconds (42.71 CPU Seconds)
  --   2006/05/19 13:24:21.92 [INFO][APPS.TT_TEST:884][My Program] <My Task> has taken 2 hours, 17 minutes, 34.06 seconds (200.98 CPU Seconds)
  --   ...
  --   2006/05/19 13:24:21.89 [INFO][APPS.TT_TEST:293][My Program] <My Task> FINISHED SUCCESSFULLY
  --   2006/05/19 13:24:21.92 [INFO][APPS.TT_TEST:884][My Program] <My Task> has taken 3 days, 18 hours, 12 seconds (2,343.62 CPU Seconds)
  --
  -- Eaxmples:
  -- =========
  --
  --   DECLARE
  --     l_task                  TT_LOG.t_task;
  --     c_program_name CONSTANT TT_LOG.T_PROGRAM_NAME := 'My Program';
  --   BEGIN
  --     -- Start the Timer
  --     l_task := TT_LOG.start_task(p_log_level      => TT_LOG.c_log_level_info,
  --                                 p_task_name      => 'My Task',
  --                                 p_copy_to_output => TRUE);
  --     ...
  --     /* Perform length task here */
  --     ...
  --
  --     -- Optionally log elapsed time thusfar
  --     TT_LOG.log_elapsed_time(p_task => l_task);
  --     ...
  --
  --     -- Stop the Timer: Successful Completion
  --     TT_LOG.stop_task(p_sqlcode      => SQLCODE,
  --                      p_sqlerrm      => SQLERRM,
  --                      p_task         => l_task);
  --   EXCEPTION WHEN OTHERS THEN
  --
  --     ...
  --
  --     -- Stop the Timer: Task Interrupted Prematurely
  --     TT_LOG.stop_task(p_sqlcode      => SQLCODE,
  --                      p_sqlerrm      => SQLERRM,
  --                      p_task         => l_task);
  --    END;
  --
  ------------------------------------------------------------------------------
  FUNCTION start_task
  (
    p_log_level IN t_log_level,
    p_task_name IN VARCHAR2,
    p_copy_to_output IN BOOLEAN,
    p_additional_depth IN NUMBER DEFAULT 0
  ) RETURN t_task;

  ------------------------------------------------------------------------------
  -- Stop a Timed Task
  --
  -- Parameters:
  -- ===========
  --
  -- P_SQLCODE
  --     Set to SQLCODE.
  --
  -- P_SQLERRM
  --     Set to SQLERRM.
  --
  -- P_TASK_NAME
  --     The task to be stopped.
  --
  -- P_ADDITIONAL_DEPTH
  --     See DETERMINE_CALLER().
  --
  -- Eaxmples:
  -- =========
  --   See START_TASK().
  --
  ------------------------------------------------------------------------------
  PROCEDURE stop_task
  (
    p_sqlcode IN NUMBER,
    p_sqlerrm IN VARCHAR2,
    p_task IN OUT t_task,
    p_additional_depth IN NUMBER DEFAULT 0
  );

  ------------------------------------------------------------------------------
  -- Replace the Date Format Mask elements in a String with their TO_CHAR()
  -- equivalent for the given date enclosed in squigly braces: '{' and '}'
  --
  -- Used when concurrent program wish to specify a date/timestamp as part of
  -- a filename for recurrent requests via SRS parameters.
  --
  -- Parameters:
  -- ===========
  --
  -- P_FILENAME
  --     The filename which includes valid characters for a datetime TO_CHAR()
  --     enclosed with '{' and '}'.
  --     If no recognized date components are in included, no replacement is
  --     performed and a warning message is logged.
  --
  -- P_DATE
  --     The date to use to TO_CHAR(). If NULL, no replacement is performed.
  --
  -- Examples:
  -- =========
  --
  --   l_filename := 'extract_{YYYYMMDD}_{HH24MISS}.txt';
  --   TT_LOG.REPLACE_DATE_FORMAT_MASK(p_filename => l_filename,
  --                                   P_date     => SYSDATE);
  --
  ------------------------------------------------------------------------------
  FUNCTION replace_date_format_mask
  (
    p_filename IN t_file_location,
    p_date IN DATE
  ) RETURN VARCHAR2;

  ------------------------------------------------------------------------------
  -- Initialize Package State
  --
  -- If you wish to change the default log destination(s), call this procedure
  -- to (re)initialize logging destination(s). A default P_DESTINATION_* parameter
  -- value of NULL will cause this package to detemrine where it should log as
  -- follows:
  -- * If running within a concurrent manager context, as determined by calling
  --   APPS.FND_GLOBAL.CONC_REQUEST_ID, logging will proceed via APPS.FND_FILE
  --   to the default concurrent manager log and out files only.
  -- * If either TRUE or FALSE is passed explicitly for any destination,
  --   logging will include that desitnation.
  -- * If not running within a concurrent manager context (e.g. if running
  --   from SQL*Plus), logging will proceed via DBMS_OUTPUT only.
  --
  -- Parameters:
  -- ===========
  --
  -- P_LOG_LEVEL
  --     See LOG().
  --
  -- P_DESTINATION_DBMS_OUTPUT
  --     * NULL has this package decide whether or not to use DBMS_OUTPUT
  --       depending on whether APPS.FND_GLOBAL.CONC_REQUEST_ID IS NULL
  --     * NULL leaves DBMS_OUTPUT unaffected if already TRUE/FALSE
  --     * TRUE forces log/out via DBMS_OUTPUT
  --     * FALSE prevents log/out via DBMS_OUTPUT
  --
  -- P_DESTINATION_FND_FILE
  --     * NULL has this package decide whether or not to use FND_FILE
  --       depending on whether APPS.FND_GLOBAL.CONC_REQUEST_ID IS NULL
  --     * NULL leaves FND_FILE unaffected if already TRUE/FALSE
  --     * TRUE forces log/out via FND_FILE
  --     * FALSE prevents log/out via FND_FILE
  --
  -- P_DESTINATION_UTL_FILE
  --     Note: UTL_FILE logging is required in order for log/out attachments
  --     to be attachable by EMAIL_COMPLETION_STATUS().
  --     * NULL has this package decide whether or not to use UTL_FILE
  --       depending on whether APPS.FND_GLOBAL.CONC_REQUEST_ID IS NULL
  --     * NULL leaves FND_FILE unaffected if already TRUE/FALSE
  --     * TRUE forces log/out via UTL_FILE
  --     * FALSE prevents log/out via UTL_FILE
  --
  ------------------------------------------------------------------------------
  PROCEDURE initialize
  (
    p_log_level IN t_log_level DEFAULT c_log_level_info,
    p_destination_dbms_output IN BOOLEAN DEFAULT NULL,
    p_destination_fnd_file IN BOOLEAN DEFAULT NULL,
    p_destination_utl_file IN BOOLEAN DEFAULT NULL
  );

END tt_log;
