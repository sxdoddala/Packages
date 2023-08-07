create or replace PACKAGE BODY tt_log IS

  -- Application Object Library Lookup for V$INSTANCE.HOSTNAME Map to SMTP Hostname
  c_smtp_map_aol_lookup r_aol_lookup_type;

  ------------------------------------------------------------------------------
  -- Concurrent Manager Related Items
  ------------------------------------------------------------------------------

  -- Map Concurrent Manager Return Values to Descriptions
  TYPE retcode_table IS TABLE OF VARCHAR2(200) INDEX BY t_retcode;
  retcode_hash retcode_table;

  -- Max line length supported by concurrent manager ERRBUF return parameter
  -- We truncate any message returned to this length
  -- * Max bind variable length in 10g is 4000
  -- * APPS.FND_CONCURRENT_REQUESTS.COMPLETION_MESSAGE is VARCHAR2(240)
  --   So, the Request Details screen will only show the first 240 characters
  -- * 11i Concurrent Manager appears to allow up to 1800 characters in the log
  c_errbuf_max_line_length CONSTANT NUMBER := 1800;

  ------------------------------------------------------------------------------
  -- Map Log Level Numeric Values to Log Level Codes
  ------------------------------------------------------------------------------

  TYPE log_level_table IS TABLE OF VARCHAR2(10) INDEX BY t_log_level;
  log_level_hash log_level_table;

  ------------------------------------------------------------------------------
  -- Exception Context Stack for Logging or Multiple Wrapped Lines
  ------------------------------------------------------------------------------

  TYPE log_line_table IS TABLE OF t_log_line INDEX BY BINARY_INTEGER;

  ------------------------------------------------------------------------------
  -- Log Targets "stdout" and "stderr"
  ------------------------------------------------------------------------------

  SUBTYPE t_log_target IS BINARY_INTEGER RANGE 1 .. 2;
  c_log_target_stdout CONSTANT t_log_target := 1;
  c_log_target_stderr CONSTANT t_log_target := 2;

  c_log_level_code_output CONSTANT t_log_level_code := 'OUTPUT';

  ------------------------------------------------------------------------------
  -- Package Private Constants
  ------------------------------------------------------------------------------

  -- Prefix for each contextual line of logging
  -- This indentation makes the contextual exceptions easier to read and find in the log file
  c_log_exception_prefix CONSTANT CHAR(2) := '  ';

  -- Date format for log timestamps
  -- Each line is time stamped with C_LOG_DATE_FORMAT format mask, suffixed with 100th's of a second
  c_log_date_format CONSTANT VARCHAR2(30) := 'YYYY-MM-DD HH24:MI:SS';

  -- Full date/time when outputting DATE values passed to SHOW_VALUE()
  c_full_date_format CONSTANT VARCHAR2(30) := 'YYYY-MM-DD HH24:MI:SS';

  -- Exception number used within this package for any so-called contextual exception.
  -- Could be any valid number accepted by RAISE_APPLICATION_ERROR(), but should preferably
  -- be used exclusively by this package, as logging messages will make more sense.
  c_context_exception_sqlcode CONSTANT NUMBER := -20999;

  -- Exception number used within this package for fatal error conditions.
  -- Used when calling RAISE_APPLICATION_ERROR() cause recursive calls.
  c_fatal_exception_sqlcode CONSTANT NUMBER := -20900;

  -- Prefix that we will look for in SQLERRM to strip off our own internal exceptions
  c_context_sqlerrm_prefix CONSTANT CHAR(11) := 'ORA' || to_char(c_context_exception_sqlcode, 'FM00000') || ': ';

  c_ora_000_sqlcode CONSTANT NUMBER := SQLCODE; --This gets set to 0
  --c_ora_000_exception_text    CONSTANT VARCHAR2(200) := SQLERRM; --This gets set to "ORA-0000: normal, successful completion"

  -- Used for internal logging and is always logged, regardless of current log level
  c_log_level_internal CONSTANT t_log_level := c_log_level_off;

  ------------------------------------------------------------------------------
  -- Private Package Global Variables
  ------------------------------------------------------------------------------

  -- Wrap DBMS_OUTPUT lines at this length
  g_dbms_output_wrap_line_length INTEGER := c_dbms_output_max_line_length;

  -- Current log level
  g_log_level t_log_level;

  -- Backtrace of any initialization failures
  g_init_failure_details t_log_line;

  -- Log destination names
  g_destination_name_dbms_output CONSTANT VARCHAR2(20) := 'DBMS_OUTPUT';
  g_destination_name_fnd_file    CONSTANT VARCHAR2(20) := 'FND_FILE';
  g_destination_name_utl_file    CONSTANT VARCHAR2(20) := 'UTL_FILE';

  g_utl_file_location_stdout t_file_location;
  g_utl_file_location_stderr t_file_location;

  -- Toggle output to specific log destinations
  -- TRUE causes logging whereas NULL or FALSE prevent logging
  g_destination_dbms_output BOOLEAN;
  g_destination_fnd_file    BOOLEAN;
  g_destination_utl_file    BOOLEAN;

  g_utl_file_stdout utl_file.file_type;
  g_utl_file_stderr utl_file.file_type;

  -- Stack of contextual information for the current exception being raised
  -- Each element in this index-by table represents one message line in the
  -- log file when LOG_CONTEXTUAL_EXCEPTION() is called.
  g_log_caller_stack  log_line_table;
  g_log_context_stack log_line_table;

  ------------------------------------------------------------------------------
  -- forward refereces
  ------------------------------------------------------------------------------
  PROCEDURE log_internal
  (
    p_message IN t_log_line,
    p_copy_to_output IN BOOLEAN DEFAULT FALSE,
    p_additional_depth IN NUMBER DEFAULT 0
  );

  ------------------------------------------------------------------------------
  -- Provide human readable string of the given log level
  ------------------------------------------------------------------------------
  FUNCTION describe_log_level(p_log_level IN t_log_level) RETURN VARCHAR2 IS
  BEGIN
    IF p_log_level IS NULL
    THEN
      RETURN 'NULL';
    ELSIF log_level_hash.EXISTS(p_log_level)
    THEN
      RETURN log_level_hash(p_log_level);
    ELSE
      RETURN 'CUSTOM LEVEL ' || show_value(p_log_level);
    END IF;
  END;

  ------------------------------------------------------------------------------
  -- Determine Calling Code Line Number and Package Name
  ------------------------------------------------------------------------------
  -- Sample Call Stack
  /*
  ----- PL/SQL Call Stack -----
    object      line  object
    handle    number  name
  20CBCC30        37  package body APPS.TT_LOG
  20CBCC30       115  package body APPS.TT_FILE_METADATA
  20BD83B0       168  package body APPS.TT_834_METADATA
  25762450         5  anonymous block
  */
  FUNCTION determine_caller(p_additional_depth IN NUMBER DEFAULT 0) RETURN VARCHAR2 IS
    l_call_stack  VARCHAR2(8000) := dbms_utility.format_call_stack;
    l_line_number VARCHAR2(20);
    l_pos1        NUMBER;
    l_pos2        NUMBER;
  BEGIN
    l_pos1        := instr(l_call_stack, chr(10), 1, 3 + 1 + p_additional_depth) + 1; -- start of nth line (n = 3 headers + p_depth callstack lines)
    l_pos2        := instr(l_call_stack, chr(10), l_pos1) - 1; -- end of nth line
    l_pos1        := instr(l_call_stack, ' ', l_pos1); -- drop leading object handle
    l_call_stack  := TRIM(substr(l_call_stack, l_pos1, l_pos2 - l_pos1 + 1)); -- extract line number + code location
    l_line_number := substr(l_call_stack, 1, instr(l_call_stack, ' ') - 1); --extract line number
    l_call_stack  := TRIM(substr(l_call_stack, length(l_line_number) + 1)); -- extract remainder of line, trim

    l_call_stack := regexp_replace(srcstr => l_call_stack, pattern => '^package body ', replacestr => ''); -- less verbose for the common case

    l_call_stack := l_call_stack || ':' || l_line_number; --put it all back together
    RETURN l_call_stack;
  END;

  ------------------------------------------------------------------------------
  -- Raise G_RETCODE
  --
  -- Raise an exception if G_RETCODE is still C_RETCODE_INVALID
  ------------------------------------------------------------------------------
  PROCEDURE raise_g_retcode(p_new_retcode IN t_retcode) IS
  BEGIN
    IF g_retcode = c_retcode_invalid
    THEN
      raise_application_error(c_context_exception_sqlcode,
                              'Please set TT_LOG.G_RETCODE := TT_LOG.C_RETCODE_SUCCESS before your first log statement' || chr(10) ||
                              dbms_utility.format_error_backtrace);
    ELSIF p_new_retcode > g_retcode
    THEN
      log_internal('Raising G_RETCODE from ' || retcode_hash(g_retcode) || ' to ' || retcode_hash(p_new_retcode) || '.');
      g_retcode := p_new_retcode;
    END IF;
  END raise_g_retcode;

  ------------------------------------------------------------------------------
  -- Set wrap line length
  ------------------------------------------------------------------------------
  PROCEDURE set_dbms_output_wrap_length(p_wrap_line_length IN INTEGER) IS
  BEGIN
    g_dbms_output_wrap_line_length := least(c_dbms_output_max_line_length, p_wrap_line_length);
  END set_dbms_output_wrap_length;

  ------------------------------------------------------------------------------
  -- Wrap Text to given length
  ------------------------------------------------------------------------------
  FUNCTION wrap
  (
    p_prefix IN VARCHAR2,
    p_text IN VARCHAR2,
    p_length NUMBER
  ) RETURN log_line_table IS
    l_wrapped_text log_line_table;
    l_pos_start    NUMBER;
    l_pos_end      NUMBER := 1;
    l_prefix       t_log_prefix;
    l_text         t_log_line;
    l_length       NUMBER;
  BEGIN
    IF p_length IS NULL
       OR p_length < 1
    THEN
      raise_application_error(c_fatal_exception_sqlcode, 'P_LENGTH MUST BE >= 1');
    END IF;

    IF length(p_prefix) >= p_length
    THEN
      l_prefix := NULL;
      l_text   := nvl(p_prefix || p_text, 'NULL');
      l_length := p_length;
    ELSE
      l_prefix := p_prefix;
      l_text   := nvl(p_text, 'NULL');
      l_length := p_length - nvl(length(p_prefix), 0);
    END IF;

    --    l_wrapped_text(l_wrapped_text.COUNT) := 'l_prefix = ' || nvl(l_prefix, '*NULL*');
    --    l_wrapped_text(l_wrapped_text.COUNT) := 'l_text = ' || nvl(l_text, '*NULL*');
    --    l_wrapped_text(l_wrapped_text.COUNT) := 'l_length = ' || nvl(l_length, -99999);
    WHILE l_pos_end <= length(l_text)
    LOOP
      l_pos_start := l_pos_end;
      l_pos_end := least(l_pos_start + l_length, length(l_text) + 1);
      l_wrapped_text(l_wrapped_text.COUNT) := l_prefix || substr(l_text, l_pos_start, l_pos_end - l_pos_start);
    END LOOP;
    RETURN l_wrapped_text;
  END wrap;

  ------------------------------------------------------------------------------
  -- Attempt to report buffer overflow and other exceptions with DBMS_OUTPUT
  ------------------------------------------------------------------------------
  PROCEDURE handle_dbms_output_exception(p_sqlerrm IN VARCHAR2) IS
    l_line   t_log_line;
    l_status NUMBER;
  BEGIN
    dbms_output.get_line(line => l_line, status => l_status);
    dbms_output.put_line('** DBMS_OUTPUT LOG FAILURE -- EXCEPTION CALLING DBMS_OUTPUT.PUT_LINE() **');
    dbms_output.put_line('** YOU MAY NEED TO CALL DBMS_OUTPUT.ENABLE() WITH A LARGER BUFFER SIZE **');
    dbms_output.put_line(p_sqlerrm);
    dbms_output.put_line('');
    dbms_output.put_line('** LOG CLEARED AND PROCEEEDING **');
  EXCEPTION
    WHEN OTHERS THEN
      NULL; -- ignore; nothing more we can do
  END handle_dbms_output_exception;

  ------------------------------------------------------------------------------
  -- Log Raw
  ------------------------------------------------------------------------------
  PROCEDURE log_raw
  (
    p_log_target IN t_log_target,
    p_log_prefix IN VARCHAR2,
    p_single_line IN VARCHAR2
  ) IS
    l_single_line  t_log_line := nvl(p_single_line, ' ');
    l_wrapped_text log_line_table;
  BEGIN
    IF g_destination_dbms_output
    THEN
      l_wrapped_text := wrap(p_prefix => p_log_prefix, p_text => l_single_line, p_length => g_dbms_output_wrap_line_length);
      BEGIN
        FOR i IN l_wrapped_text.FIRST .. l_wrapped_text.LAST
        LOOP
          dbms_output.put_line(l_wrapped_text(i));
        END LOOP;
      EXCEPTION
        WHEN OTHERS THEN
          handle_dbms_output_exception(p_sqlerrm => SQLERRM);
      END;
    END IF;

    IF g_destination_fnd_file
    THEN
      CASE p_log_target
        WHEN c_log_target_stdout THEN
          apps.fnd_file.put_line(which => apps.fnd_file.output, buff => l_single_line);
        WHEN c_log_target_stderr THEN
          apps.fnd_file.put_line(which => apps.fnd_file.log, buff => p_log_prefix || l_single_line);
      END CASE; END IF;

    IF g_destination_utl_file
    THEN
      CASE p_log_target
        WHEN c_log_target_stdout THEN
          IF g_utl_file_stdout.id IS NOT NULL
          THEN
            utl_file.put_line(file => g_utl_file_stdout, buffer => l_single_line, autoflush => TRUE);
          END IF;
        WHEN c_log_target_stderr THEN
          IF g_utl_file_stderr.id IS NOT NULL
          THEN
            utl_file.put_line(file => g_utl_file_stderr, buffer => p_log_prefix || l_single_line, autoflush => TRUE);
          END IF;
      END CASE; END IF;
  END log_raw;

  ------------------------------------------------------------------------------
  -- Log Raw Message
  ------------------------------------------------------------------------------
  PROCEDURE log_raw
  (
    p_log_target IN t_log_target,
    p_prefix IN t_log_prefix,
    p_message IN t_log_line
  ) IS
    l_pos1    NUMBER := 1;
    l_pos2    NUMBER := 1;
    l_prefix  t_log_prefix := p_prefix;
    l_message t_log_line := nvl(p_message, '--NULL LOG MESSAGE--');
  BEGIN
    IF l_message = chr(10)
    THEN
      l_message := ' ';
    ELSE
      l_message := rtrim(l_message, chr(10));

      IF p_log_target = c_log_target_stderr
      THEN
        l_message := ltrim(l_message, chr(10));
      END IF;
      l_message := nvl(l_message, ' ');
    END IF;

    LOOP
      l_pos2 := instr(l_message, chr(10), l_pos1);
      EXIT WHEN l_pos2 = 0;
      log_raw(p_log_target => p_log_target, p_log_prefix => l_prefix, p_single_line => substr(l_message, l_pos1, l_pos2 - l_pos1));
      l_pos1   := l_pos2 + 1;
      l_prefix := rpad(' ', length(l_prefix));
    END LOOP;

    log_raw(p_log_target => p_log_target, p_log_prefix => l_prefix, p_single_line => substr(l_message, l_pos1));
  END log_raw;

  ------------------------------------------------------------------------------
  -- Quote, escape or DUMP() value as needed
  ------------------------------------------------------------------------------
  FUNCTION show_value
  (
    p_value IN VARCHAR2,
    p_alternate_text_when_null IN VARCHAR2 DEFAULT 'NULL'
  ) RETURN VARCHAR2 IS
    l_value          t_log_line;
    l_us7ascii_value t_log_line := convert(src => p_value, destcset => 'US7ASCII');
  BEGIN
    IF p_value IS NULL
    THEN
      RETURN p_alternate_text_when_null;
    ELSIF p_value = l_us7ascii_value
    THEN
      RETURN '''' || p_value || '''';
    ELSE
      SELECT dump(p_value) INTO l_value FROM dual;
      RETURN '''' || l_us7ascii_value || ''' (' || l_value || ')';
    END IF;
  END show_value;

  ------------------------------------------------------------------------------
  -- Quote, escape or DUMP() value as needed
  ------------------------------------------------------------------------------
  FUNCTION show_value
  (
    p_value IN DATE,
    p_alternate_text_when_null IN VARCHAR2 DEFAULT 'NULL'
  ) RETURN VARCHAR2 IS
  BEGIN
    RETURN nvl(to_char(p_value, c_full_date_format), p_alternate_text_when_null);
  END show_value;

  ------------------------------------------------------------------------------
  -- Quote, escape or DUMP() value as needed
  ------------------------------------------------------------------------------
  FUNCTION show_value
  (
    p_value IN NUMBER,
    p_alternate_text_when_null IN VARCHAR2 DEFAULT 'NULL',
    p_format_mask IN VARCHAR2 DEFAULT c_default_number_format_mask
  ) RETURN VARCHAR2 IS
    l_text VARCHAR2(200);
  BEGIN
    IF p_format_mask = c_default_number_format_mask
    THEN
      l_text := regexp_replace(to_char(p_value, c_default_number_format_mask), '?[0]+$', '');
      l_text := rtrim(l_text, '.');
    ELSIF p_format_mask IS NULL
    THEN
      l_text := to_char(p_value);
    ELSE
      l_text := to_char(p_value, p_format_mask);
    END IF;

    IF instr(l_text, '#') > 0
    THEN
      l_text := to_char(p_value);
    END IF;
    RETURN nvl(l_text, p_alternate_text_when_null);
  END show_value;

  ------------------------------------------------------------------------------
  -- Quote, escape or DUMP() value as needed
  ------------------------------------------------------------------------------
  FUNCTION show_value
  (
    p_value IN BOOLEAN,
    p_alternate_text_when_null IN VARCHAR2 DEFAULT 'NULL'
  ) RETURN VARCHAR2 IS
  BEGIN
    IF p_value IS NULL
    THEN
      RETURN p_alternate_text_when_null;
    ELSIF p_value
    THEN
      RETURN 'TRUE';
    ELSE
      RETURN 'FALSE';
    END IF;
  END show_value;

  ------------------------------------------------------------------------------
  -- Elapsed Time to Human Readable Form
  ------------------------------------------------------------------------------
  FUNCTION show_value
  (
    p_value IN INTERVAL DAY TO SECOND,
    p_alternate_text_when_null IN VARCHAR2 DEFAULT 'NULL'
  ) RETURN VARCHAR2 IS
    l_text         VARCHAR2(200);
    l_elapsed_time INTERVAL DAY(9) TO SECOND(2) := p_value;
  BEGIN
    IF p_value IS NULL
    THEN
      RETURN p_alternate_text_when_null;
    END IF;

    -- Start with a text representation of the elapsed time
    --   BEFORE: INTERVAL DAY(9) TO SECOND(2)
    --   AFTER :  '+000000000 01:00:26.98'
    l_text := to_char(l_elapsed_time);

    -- Make it more human readable
    --   BEFORE: '+000000000 01:00:26.98'
    --   AFTER :  ', 0 days, 1 hours, 0 minutes, 26.98 seconds'
    l_text := regexp_replace(l_text,
                             '\+0*([[:digit:]]+) 0*([[:digit:]]+):0*([[:digit:]]+):0*([[:digit:]]+).([[:digit:]]+)',
                             ', \1 days, \2 hours, \3 minutes, \4.\5 seconds');

    -- Fix plurals
    --   BEFORE: ', 0 days, 1 hours, 0 minutes, 26.98 seconds'
    --   AFTER :  ', 0 days, 1 hour, 0 minutes, 26.98 seconds'
    l_text := regexp_replace(l_text, '(, 1 [[:alpha:]]+)s', '\1');

    -- Remove leading any 0 units
    --   BEFORE: ', 0 days, 1 hour, 0 minutes, 26.98 seconds'
    --   AFTER :  ', 1 hour, 0 minutes, 26.98 seconds'
    l_text := regexp_replace(l_text, '^(, 0 [[:alpha:]]+s)*', '');

    -- Remove leading ', ' which we needed for the above calls to REGEXP_REPLACE()
    --   BEFORE: ', 1 hour, 0 minutes, 26.98 seconds'
    --   AFTER :  '1 hour, 0 minutes, 26.98 seconds'
    l_text := regexp_replace(l_text, '^, ', '');

    RETURN l_text;
  END show_value;

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
  ) RETURN VARCHAR2 IS
  BEGIN
    RETURN show_value(p_value => p_value, p_alternate_text_when_null => p_alternate_text_when_null, p_format_mask => NULL);
  END show_id;

  ------------------------------------------------------------------------------
  -- Rpad as needed, but do not trim
  ------------------------------------------------------------------------------
  FUNCTION rpad_without_trim
  (
    p_text IN VARCHAR2,
    p_length IN NUMBER,
    p_pad IN VARCHAR2 DEFAULT ' '
  ) RETURN VARCHAR2 IS
  BEGIN
    IF p_text IS NULL
    THEN
      RETURN NULL;
    ELSIF length(p_text) > p_length
    THEN
      RETURN p_text;
    ELSE
      RETURN rpad(p_text, p_length, p_pad);
    END IF;
  END rpad_without_trim;

  ------------------------------------------------------------------------------
  -- Format Log Prefix
  ------------------------------------------------------------------------------
  FUNCTION make_prefix
  (
    p_log_level_code IN t_log_level_code,
    p_caller_text IN VARCHAR2
  ) RETURN VARCHAR2 IS
    l_prefix t_log_prefix;
  BEGIN
    l_prefix := to_char(SYSDATE, c_log_date_format) || '.' || to_char(MOD(dbms_utility.get_time, 100), 'FM00');

    IF p_log_level_code IS NOT NULL
    THEN
      l_prefix := l_prefix || ' [' || rpad_without_trim(p_log_level_code, 6) || ']';
    END IF;

    IF p_caller_text IS NOT NULL
    THEN
      l_prefix := l_prefix || '[' || p_caller_text || ']';
    END IF;

    l_prefix := l_prefix || ' ';

    RETURN l_prefix;
  END make_prefix;

  ------------------------------------------------------------------------------
  -- Output Message to current "out" destination(s)
  ------------------------------------------------------------------------------
  PROCEDURE output
  (
    p_message IN t_log_line,
    p_additional_depth IN NUMBER DEFAULT 0
  ) IS
    l_prefix VARCHAR2(200);
  BEGIN
    l_prefix := make_prefix(p_log_level_code => c_log_level_code_output, p_caller_text => determine_caller(p_additional_depth + 1));
    log_raw(p_log_target => c_log_target_stdout, p_prefix => l_prefix, p_message => p_message);
  END output;

  ------------------------------------------------------------------------------
  -- Remove stack trace from user output
  --
  -- For example:
  --   ORA-20999: field NM103 IS NULL at APPS.TT_FILE_METADATA:163 at APPS.TT_FILE_METADATA:804 for Dependent ....'
  -- becomes:
  --   ORA-20999: field NM103 IS NULL for Dependent ....'
  ------------------------------------------------------------------------------
  FUNCTION remove_stack_from_sqlerrm(p_sqlerrm IN VARCHAR2) RETURN VARCHAR2 IS
  BEGIN
    RETURN regexp_replace(p_sqlerrm, ' at [^ ]+\.[^ ]+:[[:digit:]]+', '');
  END remove_stack_from_sqlerrm;

  ------------------------------------------------------------------------------
  -- Error Message to "out" destination(s)
  ------------------------------------------------------------------------------
  PROCEDURE output_error
  (
    p_sqlcode IN NUMBER,
    p_sqlerrm IN VARCHAR2,
    p_message IN t_log_line
  ) IS
    l_sqlerrm t_log_line;
  BEGIN
    IF p_sqlerrm IS NOT NULL
    THEN
      l_sqlerrm := remove_stack_from_sqlerrm(p_sqlerrm);
    ELSIF p_sqlcode IS NOT NULL
    THEN
      l_sqlerrm := 'SQLCODE ' || p_sqlcode;
    ELSE
      l_sqlerrm := 'USER DEFINED ERROR';
    END IF;
    output(describe_log_level(c_log_level_error) || ': ' || l_sqlerrm || ' ' || p_message);
    raise_g_retcode(c_retcode_failure);
  END output_error;

  ------------------------------------------------------------------------------
  -- Insert into CUST.TTEC_PROCESS_ERROR Table
  ------------------------------------------------------------------------------
  PROCEDURE insert_ttec_process_error
  (
    p_log_level IN t_log_level,
    p_message IN t_log_line,
    p_additional_depth IN NUMBER DEFAULT 0
  ) IS
    l_caller       VARCHAR2(200);
    l_program_name VARCHAR2(200);
    l_status       cust.ttec_error_handling.status%TYPE;
  BEGIN
    CASE p_log_level
      WHEN c_log_level_fatal THEN
        l_status := c_ttec_error_status_failure;
      WHEN c_log_level_error THEN
        l_status := c_ttec_error_status_failure;
      WHEN c_log_level_warn THEN
        l_status := c_ttec_error_status_warning;
      WHEN c_log_level_info THEN
        l_status := c_ttec_error_status_initial;
      WHEN c_log_level_debug THEN
        l_status := c_ttec_error_status_initial;
      WHEN c_log_level_trace THEN
        l_status := c_ttec_error_status_initial;
    END CASE;

    -- Determine caller, formatted as '<program name>:<line number>'
    l_caller := determine_caller(p_additional_depth + 1);

    -- Caller without the line number
    l_program_name := regexp_replace(l_caller, ':[[:digit:]]+$', '');

    -- Insert a row into CUST.TTEC_PROCESS_ERROR via CUST.TTEC_PROCESS_ERROR
    cust.ttec_process_error(application_code => substr(fnd_global.application_short_name, 1, 3),
                            interface => substr('TT_LOG', 1, 15),
                            program_name => substr(l_program_name, 1, 30),
                            module_name => substr(l_program_name, 1, 50),
                            status => substr(l_status, 1, 7),
                            ERROR_CODE => c_context_exception_sqlcode,
                            error_message => substr(p_message, 1, 512));
  EXCEPTION
    WHEN OTHERS THEN
      raise_application_error(c_fatal_exception_sqlcode,
                              'FAILED TO LOG MESSAGE VIA CUST.TTEC_PROCESS_ERROR DUE TO ' || SQLERRM || ' WITH BACKTRACE ' ||
                              dbms_utility.format_error_backtrace);
  END insert_ttec_process_error;

  ------------------------------------------------------------------------------
  -- Log Message to current "log" destination(s)
  ------------------------------------------------------------------------------
  PROCEDURE log
  (
    p_log_level IN t_log_level,
    p_message IN t_log_line,
    p_copy_to_output IN BOOLEAN DEFAULT FALSE,
    p_additional_depth IN NUMBER DEFAULT 0
  ) IS
    l_prefix         t_log_prefix;
    l_log_level_code t_log_level_code;
  BEGIN
    IF p_log_level >= g_log_level
    THEN
      IF p_log_level = c_log_level_internal
      THEN
        l_log_level_code := '*';
      ELSE
        l_log_level_code := describe_log_level(p_log_level => p_log_level);
      END IF;

      l_prefix := make_prefix(p_log_level_code => l_log_level_code, p_caller_text => determine_caller(p_additional_depth + 1));
      log_raw(p_log_target => c_log_target_stderr, p_prefix => l_prefix, p_message => p_message);
      IF p_copy_to_output
      THEN
        l_prefix := make_prefix(p_log_level_code => c_log_level_code_output,
                                p_caller_text => determine_caller(p_additional_depth + 1));
        IF p_log_level = c_log_level_info
        THEN
          log_raw(p_log_target => c_log_target_stdout, p_prefix => l_prefix, p_message => remove_stack_from_sqlerrm(p_message));
        ELSIF p_log_level = c_log_level_internal
        THEN
          log_raw(p_log_target => c_log_target_stdout, p_prefix => l_prefix, p_message => remove_stack_from_sqlerrm(p_message));
        ELSE
          log_raw(p_log_target => c_log_target_stdout,
                  p_prefix => l_prefix,
                  p_message => l_log_level_code || ': ' || remove_stack_from_sqlerrm(p_message));
        END IF;
      END IF;
    END IF;

    IF p_log_level = c_log_level_internal
    THEN
      NULL; --don't change G_RETCODE due to our internal logging
    ELSIF p_log_level >= c_log_level_error
    THEN
      raise_g_retcode(c_retcode_failure);
      insert_ttec_process_error(p_log_level => p_log_level, p_message => p_message, p_additional_depth => p_additional_depth + 1);
    ELSIF p_log_level >= c_log_level_warn
    THEN
      raise_g_retcode(c_retcode_warning);
    END IF;

  END log;

  ------------------------------------------------------------------------------
  -- Log trace Message
  ------------------------------------------------------------------------------
  PROCEDURE trace
  (
    p_message IN t_log_line,
    p_copy_to_output IN BOOLEAN DEFAULT FALSE,
    p_additional_depth IN NUMBER DEFAULT 0
  ) IS
  BEGIN
    log(p_log_level => c_log_level_trace,
        p_message => p_message,
        p_copy_to_output => p_copy_to_output,
        p_additional_depth => p_additional_depth + 1);
  END trace;

  ------------------------------------------------------------------------------
  -- Log DEBUG Message
  ------------------------------------------------------------------------------
  PROCEDURE debug
  (
    p_message IN t_log_line,
    p_copy_to_output IN BOOLEAN DEFAULT FALSE,
    p_additional_depth IN NUMBER DEFAULT 0
  ) IS
  BEGIN
    log(p_log_level => c_log_level_debug,
        p_message => p_message,
        p_copy_to_output => p_copy_to_output,
        p_additional_depth => p_additional_depth + 1);
  END debug;

  ------------------------------------------------------------------------------
  -- Log INFO Message
  ------------------------------------------------------------------------------
  PROCEDURE info
  (
    p_message IN t_log_line,
    p_copy_to_output IN BOOLEAN DEFAULT FALSE,
    p_additional_depth IN NUMBER DEFAULT 0
  ) IS
  BEGIN
    log(p_log_level => c_log_level_info,
        p_message => p_message,
        p_copy_to_output => p_copy_to_output,
        p_additional_depth => p_additional_depth + 1);
  END info;

  ------------------------------------------------------------------------------
  -- Log WARN Message
  ------------------------------------------------------------------------------
  PROCEDURE warn
  (
    p_message IN t_log_line,
    p_copy_to_output IN BOOLEAN DEFAULT FALSE,
    p_additional_depth IN NUMBER DEFAULT 0
  ) IS
  BEGIN
    log(p_log_level => c_log_level_warn,
        p_message => p_message,
        p_copy_to_output => p_copy_to_output,
        p_additional_depth => p_additional_depth + 1);
  END warn;

  ------------------------------------------------------------------------------
  -- Log ERROR Message
  ------------------------------------------------------------------------------
  PROCEDURE error
  (
    p_message IN t_log_line,
    p_copy_to_output IN BOOLEAN DEFAULT FALSE,
    p_additional_depth IN NUMBER DEFAULT 0
  ) IS
  BEGIN
    log(p_log_level => c_log_level_error,
        p_message => p_message,
        p_copy_to_output => p_copy_to_output,
        p_additional_depth => p_additional_depth + 1);
  END error;

  ------------------------------------------------------------------------------
  -- Log fatal Message
  ------------------------------------------------------------------------------
  PROCEDURE fatal
  (
    p_message IN t_log_line,
    p_copy_to_output IN BOOLEAN DEFAULT FALSE,
    p_additional_depth IN NUMBER DEFAULT 0
  ) IS
  BEGIN
    log(p_log_level => c_log_level_fatal,
        p_message => p_message,
        p_copy_to_output => p_copy_to_output,
        p_additional_depth => p_additional_depth + 1);
  END fatal;

  ------------------------------------------------------------------------------
  -- Log Internal Message
  --
  -- Private procedure for use by this package only
  ------------------------------------------------------------------------------
  PROCEDURE log_internal
  (
    p_message IN t_log_line,
    p_copy_to_output IN BOOLEAN DEFAULT FALSE,
    p_additional_depth IN NUMBER DEFAULT 0
  ) IS
    l_old_destination_dbms_output BOOLEAN;
    l_old_destination_fnd_file    BOOLEAN;
    l_old_destination_utl_file    BOOLEAN;
  BEGIN
    -- save old values
    l_old_destination_dbms_output := g_destination_dbms_output;
    l_old_destination_fnd_file    := g_destination_fnd_file;
    l_old_destination_utl_file    := g_destination_utl_file;

    -- temporarily turn on all logging destinations
    g_destination_dbms_output := TRUE;
    g_destination_fnd_file    := TRUE;
    g_destination_utl_file    := TRUE;

    -- log message
    log(p_log_level => c_log_level_internal,
        p_message => p_message,
        p_copy_to_output => p_copy_to_output,
        p_additional_depth => p_additional_depth + 1);

    -- restore saved values
    g_destination_dbms_output := l_old_destination_dbms_output;
    g_destination_fnd_file    := l_old_destination_fnd_file;
    g_destination_utl_file    := l_old_destination_utl_file;
  END log_internal;

  ------------------------------------------------------------------------------
  -- Set Log Level
  ------------------------------------------------------------------------------
  PROCEDURE set_log_level(p_log_level IN t_log_level) IS
  BEGIN
    assert(p_condition => p_log_level != c_log_level_off, p_condition_text => 'Log Level may not be OFF');

    IF g_log_level IS NULL
    THEN
      log_internal('Setting log level to ' || describe_log_level(p_log_level));
    ELSIF g_log_level = p_log_level
    THEN
      log_internal('Log level remains ' || describe_log_level(p_log_level));
    ELSE
      log_internal('Changing log level from ' || describe_log_level(g_log_level) || ' to ' || describe_log_level(p_log_level));
    END IF;
    g_log_level := p_log_level;

    FOR log_level IN log_level_hash.FIRST .. log_level_hash.LAST - 1
    LOOP
      IF log_level < g_log_level
      THEN
        log_internal(' => ' || describe_log_level(log_level) || ' messages will be SUPPRESSED');
      ELSE
        log_internal(' => ' || describe_log_level(log_level) || ' messages will be displayed');
      END IF;
    END LOOP;
  END;

  ------------------------------------------------------------------------------
  -- Set Log Level based on code
  ------------------------------------------------------------------------------
  PROCEDURE set_log_level(p_log_level_code IN t_log_level_code) IS
  BEGIN
    FOR log_level IN log_level_hash.FIRST .. log_level_hash.LAST
    LOOP
      IF p_log_level_code = log_level_hash(log_level)
      THEN
        set_log_level(log_level);
        RETURN;
      END IF;
    END LOOP;
    raise_contextual_exception(p_sqlcode => SQLCODE,
                               p_sqlerrm => SQLERRM,
                               p_backtrace => dbms_utility.format_error_backtrace,
                               p_context => 'Unrecognized log level code ' || show_value(p_log_level_code));
  END;

  ------------------------------------------------------------------------------
  -- Get Current Log Level
  ------------------------------------------------------------------------------
  FUNCTION get_log_level RETURN t_log_level IS
  BEGIN
    RETURN g_log_level;
  END;

  ------------------------------------------------------------------------------
  -- Are TRACE messages being logged?
  ------------------------------------------------------------------------------
  FUNCTION trace_enabled RETURN BOOLEAN IS
  BEGIN
    RETURN g_log_level <= c_log_level_trace;
  END;

  ------------------------------------------------------------------------------
  -- Are DEBUG messages being logged?
  ------------------------------------------------------------------------------
  FUNCTION debug_enabled RETURN BOOLEAN IS
  BEGIN
    RETURN g_log_level <= c_log_level_debug;
  END;

  ------------------------------------------------------------------------------
  -- Are INFO messages being logged?
  ------------------------------------------------------------------------------
  FUNCTION info_enabled RETURN BOOLEAN IS
  BEGIN
    RETURN g_log_level <= c_log_level_info;
  END;

  ------------------------------------------------------------------------------
  -- Are WARN messages being logged?
  ------------------------------------------------------------------------------
  FUNCTION warn_enabled RETURN BOOLEAN IS
  BEGIN
    RETURN g_log_level <= c_log_level_warn;
  END;

  ------------------------------------------------------------------------------
  -- Are ERROR messages being logged?
  ------------------------------------------------------------------------------
  FUNCTION error_enabled RETURN BOOLEAN IS
  BEGIN
    RETURN g_log_level <= c_log_level_error;
  END;

  ------------------------------------------------------------------------------
  -- Are FATAL messages being logged?
  ------------------------------------------------------------------------------
  FUNCTION fatal_enabled RETURN BOOLEAN IS
  BEGIN
    RETURN g_log_level <= c_log_level_fatal;
  END;

  ------------------------------------------------------------------------------
  -- Trasition Logging Destination
  ------------------------------------------------------------------------------
  PROCEDURE transition_logging_destination
  (
    p_global_flag IN OUT BOOLEAN,
    p_new_value IN BOOLEAN,
    p_destination_name IN VARCHAR2
  ) IS
    l_old_value BOOLEAN;
    l_new_value BOOLEAN;
  BEGIN
    l_old_value := nvl(p_global_flag, FALSE);
    l_new_value := nvl(p_new_value, FALSE);

    IF l_old_value = l_new_value
    THEN
      log_internal('Logging via ' || p_destination_name || ' remains ' || show_value(l_old_value));
    ELSE
      log_internal('Logging via ' || p_destination_name || ' transitioning from ' || show_value(l_old_value) || ' to ' ||
                   show_value(l_new_value));

      IF l_new_value
      THEN
        -- Turning logging on

        -- Generate names based on concurrent request id or session id
        g_utl_file_location_stdout := coalesce(fnd_global.conc_request_id, userenv('SESSIONID')) || '.out';
        g_utl_file_location_stderr := coalesce(fnd_global.conc_request_id, userenv('SESSIONID')) || '.log';

        -- Open files for writing
        g_utl_file_stdout := utl_file.fopen(location => c_utl_file_directory,
                                            filename => g_utl_file_location_stdout,
                                            open_mode => 'w',
                                            max_linesize => NULL);
        g_utl_file_stderr := utl_file.fopen(location => c_utl_file_directory,
                                            filename => g_utl_file_location_stderr,
                                            open_mode => 'w',
                                            max_linesize => NULL);

        -- Make global filenames fully qualified
        g_utl_file_location_stdout := c_utl_file_directory || '/' || g_utl_file_location_stdout;
        g_utl_file_location_stderr := c_utl_file_directory || '/' || g_utl_file_location_stderr;
      ELSE
        -- Turning logging off
        utl_file.fclose(file => g_utl_file_stdout);
        utl_file.fclose(file => g_utl_file_stderr);
      END IF;
    END IF;

    -- Update the global variable
    p_global_flag := p_new_value;

  END transition_logging_destination;

  ------------------------------------------------------------------------------
  -- Place additional log context on our stack
  ------------------------------------------------------------------------------
  PROCEDURE add_log_context
  (
    p_caller IN VARCHAR2,
    p_context IN t_log_line
  ) IS
  BEGIN
    g_log_caller_stack(g_log_caller_stack.COUNT + 1) := p_caller;
    g_log_context_stack(g_log_context_stack.COUNT + 1) := p_context;
  END;

  ------------------------------------------------------------------------------
  -- Parse Backtrace from DBMS_UTILITY.FORMAT_ERROR_BACKTRACE
  --
  -- 1st example of text to parse:
  --   ORA-06512: at "APPS.TT_LOG", line 423
  --   ORA-06512: at "APPS.TT_FILE_METADATA", line 172
  --   ORA-06512: at "APPS.TT_FILE_METADATA", line 682
  --
  -- 2nd example of text to parse:
  --   ORA-06512: at line 682
  ------------------------------------------------------------------------------
  FUNCTION parse_backtrace(p_backtrace IN t_log_line) RETURN VARCHAR2 IS
    c_regexp1 CONSTANT VARCHAR2(100) := '^[^-]+-[[:digit:]]+: at line ([[:digit:]]+).*';
    c_regexp2 CONSTANT VARCHAR2(100) := '^[^-]+-[[:digit:]]+: at "([^"]+)", line ([[:digit:]]+).*';
  BEGIN
    IF regexp_instr(srcstr => p_backtrace, pattern => c_regexp1, occurrence => 1, modifier => 'n') > 0
    THEN
      RETURN regexp_replace(srcstr => p_backtrace,
                            pattern => c_regexp1,
                            replacestr => 'anonymous PL/SQL block:\1',
                            occurrence => 1,
                            modifier => 'n');
    ELSE
      RETURN regexp_replace(srcstr => p_backtrace, pattern => c_regexp2, replacestr => '\1:\2', occurrence => 1, modifier => 'n');
    END IF;
  END;

  ------------------------------------------------------------------------------
  -- Place additional log context on our stack
  ------------------------------------------------------------------------------
  PROCEDURE add_log_context
  (
    p_sqlcode IN NUMBER,
    p_sqlerrm IN VARCHAR2,
    p_backtrace IN t_log_line,
    p_context IN t_log_line,
    p_additional_depth IN NUMBER
  ) IS
    l_caller VARCHAR2(200);
  BEGIN
    l_caller := nvl(parse_backtrace(p_backtrace), determine_caller(p_additional_depth + 1));

    IF g_log_caller_stack.COUNT = 0
    THEN
      IF p_sqlcode = c_ora_000_sqlcode
      THEN
        add_log_context(p_caller => l_caller, p_context => c_context_sqlerrm_prefix || 'USER DEFINED EXCEPTION ' || p_context);
      ELSIF p_sqlcode = c_context_exception_sqlcode
      THEN
        add_log_context(p_caller => l_caller, p_context => p_sqlerrm || ' ' || p_context);
      ELSE
        add_log_context(p_caller => l_caller, p_context => p_sqlerrm || ' ' || p_context);
      END IF;
    ELSE
      add_log_context(p_caller => l_caller, p_context => p_context);
    END IF;
  END add_log_context;

  ------------------------------------------------------------------------------
  -- Raise Contextual Exception
  ------------------------------------------------------------------------------
  PROCEDURE raise_contextual_exception
  (
    p_sqlcode IN NUMBER,
    p_sqlerrm IN VARCHAR2,
    p_backtrace IN t_log_line,
    p_context IN t_log_line
  ) IS
    l_sqlerrm VARCHAR2(2000);
  BEGIN
    IF g_log_context_stack.COUNT = 0
    THEN
      IF p_sqlcode = c_ora_000_sqlcode
      THEN
        l_sqlerrm := 'USER DEFINED EXCEPTION';
      ELSE
        l_sqlerrm := p_sqlerrm;
      END IF;
    ELSE
      l_sqlerrm := regexp_replace(p_sqlerrm, '^' || c_context_sqlerrm_prefix, '');
    END IF;
    add_log_context(p_sqlcode => p_sqlcode,
                    p_sqlerrm => l_sqlerrm,
                    p_backtrace => p_backtrace,
                    p_context => p_context,
                    p_additional_depth => 1);
    raise_g_retcode(c_retcode_failure);
    raise_application_error(c_context_exception_sqlcode, l_sqlerrm || ' at ' || determine_caller(1));
  END raise_contextual_exception;

  ------------------------------------------------------------------------------
  -- Log Message
  ------------------------------------------------------------------------------
  PROCEDURE log_contextual_exception
  (
    p_log_level IN t_log_level,
    p_sqlcode IN NUMBER,
    p_sqlerrm IN VARCHAR2,
    p_backtrace IN t_log_line,
    p_context IN t_log_line
  ) IS
    l_prefix VARCHAR2(200);
  BEGIN
    add_log_context(p_sqlcode => p_sqlcode,
                    p_sqlerrm => p_sqlerrm,
                    p_backtrace => p_backtrace,
                    p_context => p_context,
                    p_additional_depth => 1);

    log(p_log_level => p_log_level, p_message => 'CONTEXTUAL EXCEPTION:', p_additional_depth => 1);

    IF p_log_level >= g_log_level
    THEN
      FOR i IN g_log_caller_stack.FIRST .. g_log_caller_stack.LAST
      LOOP
        IF g_log_caller_stack(i) IS NOT NULL
        THEN
          l_prefix := c_log_exception_prefix || '(' || i || ') at [' || g_log_caller_stack(i) || '] ';
        ELSE
          l_prefix := c_log_exception_prefix;
        END IF;
        log_raw(p_log_target => c_log_target_stderr, p_prefix => l_prefix, p_message => nvl(g_log_context_stack(i), ' '));
      END LOOP;
    END IF;

    g_log_caller_stack.DELETE;
    g_log_context_stack.DELETE;

    raise_g_retcode(c_retcode_failure);
  END log_contextual_exception;

  ------------------------------------------------------------------------------
  -- Lookup Security Group Name
  ------------------------------------------------------------------------------
  FUNCTION get_security_group_name(p_security_group_id IN NUMBER) RETURN VARCHAR2 IS
    l_security_group_name fnd_security_groups_vl.security_group_name%TYPE;
  BEGIN
    SELECT security_group_name
    INTO   l_security_group_name
    FROM   fnd_security_groups_vl
    WHERE  security_group_id = p_security_group_id;

    RETURN l_security_group_name;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN 'security_group_id=' || show_id(p_security_group_id);
  END get_security_group_name;

  ------------------------------------------------------------------------------
  -- Lookup Business Group Name
  ------------------------------------------------------------------------------
  FUNCTION get_business_group_name(p_business_group_id IN NUMBER) RETURN VARCHAR2 IS
    l_business_group_name per_business_groups.NAME%TYPE;
  BEGIN
    SELECT NAME INTO l_business_group_name FROM per_business_groups WHERE business_group_id = p_business_group_id;

    RETURN l_business_group_name;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN 'business_group_id=' || show_id(p_business_group_id);
  END get_business_group_name;

  ------------------------------------------------------------------------------
  -- Describe Descriptive Flexfield
  ------------------------------------------------------------------------------
  FUNCTION describe_descriptive_flexfield(p_descriptive_flexfield IN r_descriptive_flexfield) RETURN VARCHAR2 IS
    l_text VARCHAR2(8000);
  BEGIN
    l_text := 'Descriptive Flexfield:' || chr(10);
    l_text := l_text || ' Navigation Path: ' || show_value(p_descriptive_flexfield.navigation_path) || chr(10);
    l_text := l_text || ' Title: ' || show_value(p_descriptive_flexfield.title) || chr(10);
    l_text := l_text || ' Context Code: ' || show_value(p_descriptive_flexfield.descriptive_flex_context_code) || chr(10);
    l_text := l_text || ' Segment Name: ' || show_value(p_descriptive_flexfield.end_user_column_name) || chr(10);

    RETURN l_text;
  END describe_descriptive_flexfield;

  ------------------------------------------------------------------------------
  -- Get Descriptive Flexfield
  ------------------------------------------------------------------------------
  FUNCTION get_descriptive_flexfield
  (
    p_application_short_name IN fnd_application.application_short_name%TYPE,
    p_descriptive_flexfield_name IN fnd_descriptive_flexs_vl.descriptive_flexfield_name%TYPE,
    p_descriptive_flex_ctx_code IN fnd_descr_flex_column_usages.descriptive_flex_context_code%TYPE DEFAULT 'Global Data Elements',
    p_application_column_name IN fnd_descr_flex_column_usages.application_column_name%TYPE,
    p_navigation_path IN t_navigation_path
  ) RETURN r_descriptive_flexfield IS
    l_descriptive_flexfield r_descriptive_flexfield;
  BEGIN
    l_descriptive_flexfield.application_short_name        := p_application_short_name;
    l_descriptive_flexfield.descriptive_flexfield_name    := p_descriptive_flexfield_name;
    l_descriptive_flexfield.descriptive_flex_context_code := p_descriptive_flex_ctx_code;
    l_descriptive_flexfield.application_column_name       := p_application_column_name;
    l_descriptive_flexfield.navigation_path               := p_navigation_path;

    BEGIN
      SELECT dff.title
      INTO   l_descriptive_flexfield.title
      FROM   fnd_application          app,
             fnd_descriptive_flexs_vl dff

      WHERE  app.application_short_name = l_descriptive_flexfield.application_short_name
      AND    dff.application_id = app.application_id
      AND    dff.descriptive_flexfield_name = l_descriptive_flexfield.descriptive_flexfield_name;
    EXCEPTION
      WHEN OTHERS THEN
        raise_contextual_exception(p_sqlcode => SQLCODE,
                                   p_sqlerrm => SQLERRM,
                                   p_backtrace => dbms_utility.format_error_backtrace,
                                   p_context => 'locating the ' || show_value(l_descriptive_flexfield.descriptive_flexfield_name) ||
                                                ' Descriptive Flexfield');
    END;

    BEGIN
      SELECT dffu.end_user_column_name
      INTO   l_descriptive_flexfield.end_user_column_name
      FROM   fnd_application              app,
             fnd_descr_flex_column_usages dffu
      WHERE  app.application_short_name = l_descriptive_flexfield.application_short_name
      AND    dffu.application_id = app.application_id
      AND    dffu.descriptive_flexfield_name = l_descriptive_flexfield.descriptive_flexfield_name
      AND    dffu.descriptive_flex_context_code = l_descriptive_flexfield.descriptive_flex_context_code
      AND    dffu.application_column_name = l_descriptive_flexfield.application_column_name;
    EXCEPTION
      WHEN OTHERS THEN
        raise_contextual_exception(p_sqlcode => SQLCODE,
                                   p_sqlerrm => SQLERRM,
                                   p_backtrace => dbms_utility.format_error_backtrace,
                                   p_context => 'locating the ' || show_value(l_descriptive_flexfield.application_column_name) ||
                                                ' segment for the ' ||
                                                show_value(l_descriptive_flexfield.descriptive_flexfield_name) ||
                                                ' Descriptive Flexfield');
    END;

    RETURN l_descriptive_flexfield;
  END get_descriptive_flexfield;

  ------------------------------------------------------------------------------
  -- Describe Application Object Library Lookup
  ------------------------------------------------------------------------------
  FUNCTION describe_aol_lookup_type(p_aol_lookup_type IN r_aol_lookup_type) RETURN VARCHAR2 IS
    l_text VARCHAR2(8000);
  BEGIN
    l_text := 'Application Object Library Lookup:' || chr(10);
    l_text := l_text || ' Initialized: ' || show_value(p_aol_lookup_type.initialized) || chr(10);
    l_text := l_text || ' Navigation Path: ' || show_value(p_aol_lookup_type.navigation_path) || chr(10);
    l_text := l_text || ' Application Short Name: ' || show_value(p_aol_lookup_type.application_short_name) || chr(10);
    l_text := l_text || ' View Application Short Name: ' || show_value(p_aol_lookup_type.view_application_short_name) || chr(10);
    l_text := l_text || ' Type: ' || show_value(p_aol_lookup_type.lookup_type) || chr(10);
    l_text := l_text || ' Description: ' || show_value(p_aol_lookup_type.description) || chr(10);

    RETURN l_text;
  END describe_aol_lookup_type;

  ------------------------------------------------------------------------------
  -- Get Application Object Library Lookup Type
  ------------------------------------------------------------------------------
  FUNCTION get_aol_lookup_type
  (
    p_application_short_name IN fnd_application.application_short_name%TYPE DEFAULT 'CUST',
    p_view_application_short_name IN fnd_application.application_short_name%TYPE DEFAULT 'FND',
    p_lookup_type IN fnd_lookup_types_vl.lookup_type%TYPE,
    p_navigation_path IN t_navigation_path
  ) RETURN r_aol_lookup_type IS
    l_aol_lookup_type r_aol_lookup_type;
  BEGIN
    l_aol_lookup_type.application_short_name      := p_application_short_name;
    l_aol_lookup_type.view_application_short_name := p_view_application_short_name;
    l_aol_lookup_type.lookup_type                 := p_lookup_type;
    l_aol_lookup_type.navigation_path             := p_navigation_path;

    SELECT t.description,
           a.application_id,
           va.application_id
    INTO   l_aol_lookup_type.description,
           l_aol_lookup_type.application_id,
           l_aol_lookup_type.view_application_id
    FROM   fnd_lookup_types_vl t,
           fnd_application     a,
           fnd_application     va
    WHERE  t.lookup_type = l_aol_lookup_type.lookup_type
    AND    t.application_id = a.application_id
    AND    a.application_short_name = p_application_short_name
    AND    t.view_application_id = va.application_id
    AND    va.application_short_name = p_view_application_short_name
    AND    t.security_group_id = fnd_global.lookup_security_group(t.lookup_type, t.view_application_id);

    IF debug_enabled
    THEN
      log_internal(p_message => 'Retrieved ' || describe_aol_lookup_type(l_aol_lookup_type), p_additional_depth => 1);
    END IF;

    l_aol_lookup_type.initialized := TRUE;
    RETURN l_aol_lookup_type;
  EXCEPTION
    WHEN OTHERS THEN
      raise_contextual_exception(p_sqlcode => SQLCODE,
                                 p_sqlerrm => SQLERRM,
                                 p_backtrace => dbms_utility.format_error_backtrace,
                                 p_context => 'locating the ' || show_value(l_aol_lookup_type.lookup_type) ||
                                              ' Application Object Library Lookup');

  END get_aol_lookup_type;

  ------------------------------------------------------------------------------
  -- Get Application Object Library Lookup Value
  ------------------------------------------------------------------------------
  FUNCTION get_aol_lookup_value
  (
    p_aol_lookup_type IN r_aol_lookup_type,
    p_lookup_code IN fnd_lookup_values_vl.lookup_code%TYPE
  ) RETURN r_aol_lookup_value IS
    l_aol_lookup_value r_aol_lookup_value;
  BEGIN
    l_aol_lookup_value.aol_lookup_type := p_aol_lookup_type;
    l_aol_lookup_value.lookup_code     := p_lookup_code;

    SELECT v.meaning,
           v.description
    INTO   l_aol_lookup_value.meaning,
           l_aol_lookup_value.description
    FROM   fnd_lookup_values_vl v,
           fnd_application      va
    WHERE  v.lookup_type = p_aol_lookup_type.lookup_type
    AND    v.view_application_id = va.application_id
    AND    va.application_short_name = p_aol_lookup_type.view_application_short_name
    AND    v.lookup_code = l_aol_lookup_value.lookup_code;

    RETURN l_aol_lookup_value;
  END get_aol_lookup_value;

  ------------------------------------------------------------------------------
  -- Assert Condition
  ------------------------------------------------------------------------------
  PROCEDURE assert
  (
    p_condition IN BOOLEAN,
    p_condition_text IN VARCHAR2 DEFAULT NULL,
    p_neg_condition_text IN VARCHAR2 DEFAULT NULL,
    p_context IN t_log_line DEFAULT NULL,
    p_copy_to_output IN BOOLEAN DEFAULT FALSE
  ) IS
    l_message t_log_line;
  BEGIN
    IF p_condition IS NULL
       OR NOT p_condition
    THEN
      IF p_condition_text IS NOT NULL
      THEN
        l_message := '(' || p_condition_text || ') IS NOT TRUE';
      ELSIF p_neg_condition_text IS NOT NULL
      THEN
        l_message := p_neg_condition_text;
      ELSE
        l_message := 'ASSERTION FAILED';
      END IF;

      IF p_context IS NOT NULL
      THEN
        l_message := l_message || ' ' || p_context;
      END IF;

      IF p_copy_to_output
      THEN
        output_error(p_sqlcode => c_context_exception_sqlcode, p_sqlerrm => c_context_sqlerrm_prefix, p_message => l_message);
      END IF;

      add_log_context(p_caller => determine_caller(1), p_context => c_context_sqlerrm_prefix || l_message);
      raise_application_error(c_context_exception_sqlcode, l_message);
    END IF;
  END;

  ------------------------------------------------------------------------------
  -- Map a logical directory component (from DBA_DIRECTORIES) of a filename to
  -- its physical location, or return the original location if such a mapping
  -- cannot be preformed
  ------------------------------------------------------------------------------
  FUNCTION filename_logical_to_physical(p_directory_and_filename IN t_file_location) RETURN VARCHAR2 IS
    l_directory t_file_location;
    l_pos       INTEGER;
  BEGIN
    l_pos := regexp_instr(srcstr => p_directory_and_filename, pattern => '[/\\]');
    IF l_pos IS NULL
    THEN
      -- P_DIRECTORY_AND_FILENAME was probably null
      l_directory := NULL;
    ELSIF l_pos = 0
    THEN
      -- Assume P_DIRECTORY_AND_FILENAME is a directory without a filename component
      SELECT d.directory_path INTO l_directory FROM dba_directories d WHERE d.directory_name = p_directory_and_filename;
    ELSE
      -- Assume P_DIRECTORY_AND_FILENAME is a directory and a filename
      SELECT d.directory_path
      INTO   l_directory
      FROM   dba_directories d
      WHERE  d.directory_name = substr(p_directory_and_filename, 1, l_pos - 1);
      l_directory := l_directory || substr(p_directory_and_filename, l_pos);
    END IF;
    RETURN l_directory;
  EXCEPTION
    WHEN OTHERS THEN
      -- When all else fails, return original string
      RETURN p_directory_and_filename;
  END;

  ------------------------------------------------------------------------------
  -- Determine P_PROGRAM_RETCODE and P_PROGRAM_STATUS_MESSAGE
  -- based on G_RETCODE, P_SQLCODE, P_SQLERRM
  ------------------------------------------------------------------------------
  PROCEDURE determine_errbuf_retcode
  (
    p_sqlcode IN NUMBER,
    p_sqlerrm IN VARCHAR2,
    p_program_name IN VARCHAR2,
    p_program_status_message OUT VARCHAR2,
    p_program_retcode OUT t_retcode
  ) IS
  BEGIN
    CASE g_retcode
      WHEN c_retcode_init_failed THEN
        p_program_retcode        := c_retcode_failure;
        p_program_status_message := p_program_name || ' FAILED DUE TO TT_LOG PACKAGE INITIALIZATION FAILURE' || chr(10) ||
                                    g_init_failure_details;
      WHEN c_retcode_invalid THEN
        p_program_retcode        := c_retcode_failure;
        p_program_status_message := p_program_name ||
                                    ' FAILED BECAUSE OF INVALID VALUE FOR G_RETCODE; Please set G_RETCODE to C_RETCODE_SUCCESS at the beginnning of your program and rerun';
      WHEN c_retcode_failure THEN
        p_program_retcode := c_retcode_failure;
        IF p_sqlcode = c_ora_000_sqlcode
        THEN
          p_program_status_message := p_program_name || ' FAILED WITH ERRORS; SEE LOG FOR DETAILS';
        ELSE
          p_program_status_message := p_program_name || ' FAILED WITH ' || remove_stack_from_sqlerrm(p_sqlerrm);
        END IF;
      WHEN c_retcode_warning THEN
        p_program_retcode        := c_retcode_warning;
        p_program_status_message := p_program_name || ' COMPLETED WITH WARNING; SEE LOG FOR DETAILS';
      WHEN c_retcode_success THEN
        p_program_retcode        := c_retcode_success;
        p_program_status_message := p_program_name || ' COMPLETED SUCCESSFULLY';
    END CASE;

    IF p_sqlcode != c_ora_000_sqlcode
    THEN
      raise_g_retcode(c_retcode_failure);
    END IF;
  END determine_errbuf_retcode;

  ------------------------------------------------------------------------------
  -- Get Sitename Profile Option Value
  ------------------------------------------------------------------------------
  FUNCTION get_sitename RETURN VARCHAR2 IS
    l_sitename fnd_profile_option_values.profile_option_value%TYPE;
  BEGIN
    fnd_profile.get(NAME => c_sitename_profile_option, val => l_sitename);
    RETURN nvl(l_sitename, 'Profile Options ' || show_value(c_sitename_profile_option) || ' has NULL value');
  END get_sitename;

  ------------------------------------------------------------------------------
  -- Lookup SMTP Hostname
  ------------------------------------------------------------------------------
  FUNCTION get_smtp_hostname RETURN VARCHAR2 IS
    l_hostname v$instance.host_name%TYPE;
    --    l_sitename fnd_profile_option_values.profile_option_value%TYPE;
    l_aol_lookup_value r_aol_lookup_value;
  BEGIN
    BEGIN
      log_internal('Retrieving HOST_NAME from V$INSTANCE');
      SELECT upper(host_name) INTO l_hostname FROM v$instance;
      log_internal('UPPER(V$INSTANCE.HOST_NAME) = ' || show_value(l_hostname));
    EXCEPTION
      WHEN OTHERS THEN
        raise_contextual_exception(p_sqlcode => SQLCODE,
                                   p_sqlerrm => SQLERRM,
                                   p_backtrace => dbms_utility.format_error_backtrace,
                                   p_context => 'Retrieving HOST_NAME from V$INSTANCE');
    END;

    BEGIN
      log_internal('Retrieving Lookup Code ' || show_value(l_hostname) || ' for AOL Lookup ' ||
                   describe_aol_lookup_type(c_smtp_map_aol_lookup));
      l_aol_lookup_value := get_aol_lookup_value(p_aol_lookup_type => c_smtp_map_aol_lookup, p_lookup_code => l_hostname);
      log_internal('SMTP Hostname (Lookup Code Description) = ' || show_value(l_aol_lookup_value.description));

      RETURN l_aol_lookup_value.description;
    EXCEPTION
      WHEN OTHERS THEN
        raise_contextual_exception(p_sqlcode => SQLCODE,
                                   p_sqlerrm => SQLERRM,
                                   p_backtrace => dbms_utility.format_error_backtrace,
                                   p_context => 'Retrieving Lookup Code ' || show_value(l_hostname) || ' for ' ||
                                                show_value(c_smtp_map_aol_lookup.lookup_type));
    END;
  END get_smtp_hostname;

  ------------------------------------------------------------------------------
  -- Email Completion Status
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
  ) IS
    l_smtp_server            fnd_lookup_values_vl.description%TYPE;
    l_from_email             fnd_lookup_values_vl.description%TYPE;
    l_to_email               fnd_lookup_values_vl.description%TYPE;
    l_cc_email               fnd_lookup_values_vl.description%TYPE;
    l_bcc_email              fnd_lookup_values_vl.description%TYPE;
    l_notify_success         fnd_lookup_values_vl.description%TYPE;
    l_notify_warning         fnd_lookup_values_vl.description%TYPE;
    l_notify_failure         fnd_lookup_values_vl.description%TYPE;
    l_attach_output          fnd_lookup_values_vl.description%TYPE;
    l_attach_log             fnd_lookup_values_vl.description%TYPE;
    l_attachment_locations   file_location_table;
    l_program_name           t_log_line;
    l_message                t_log_line;
    l_attachment_message     t_log_line;
    l_email_status           NUMBER;
    l_email_mesg             t_log_line;
    l_program_retcode        NUMBER;
    l_program_status_message t_log_line;
    l_subject                t_log_line;
  BEGIN
    IF NOT p_email_aol_lookup_type.initialized
    THEN
      log_internal('Skipping email because P_EMAIL_AOL_LOOKUP_TYPE is unitialized', p_copy_messages_to_output);
      RETURN;
    END IF;

    -- Set Program Name
    l_program_name := nvl(p_program_name, determine_caller(1));

    --Set L_PROGRAM_STATUS_MESSAGE and L_PROGRAM_RETCODE based on G_RETCODE, P_SQLCODE, P_SQLERRM
    determine_errbuf_retcode(p_sqlcode => p_sqlcode,
                             p_sqlerrm => p_sqlerrm,
                             p_program_name => l_program_name,
                             p_program_status_message => l_program_status_message,
                             p_program_retcode => l_program_retcode);

    IF fnd_global.conc_request_id IS NOT NULL
    THEN
      l_subject := 'Request ' || fnd_global.conc_request_id || ' ' || l_program_status_message;
    ELSE
      l_subject := nvl(l_program_status_message, '(No Subject)');
    END IF;

    -- Determine SMTP Hostname
    l_smtp_server := get_smtp_hostname;

    -- Get Email Distribution Configuration
    IF debug_enabled
    THEN
      log_internal('Using ' || describe_aol_lookup_type(p_email_aol_lookup_type), p_copy_messages_to_output);
    END IF;
    SELECT MAX(decode(upper(lookup_code), c_from_code, description, NULL)) from_email,
           MAX(decode(upper(lookup_code), c_to_code, description, NULL)) to_email,
           MAX(decode(upper(lookup_code), c_cc_code, description, NULL)) cc_email,
           MAX(decode(upper(lookup_code), c_bcc_code, description, NULL)) bc_email,
           MAX(decode(upper(lookup_code),
                      c_notify_success_code,
                      decode(upper(substr(description, 1, 1)), 'Y', 'Y', 'N', 'N', NULL),
                      NULL)) notify_success,
           MAX(decode(upper(lookup_code),
                      c_notify_warning_code,
                      decode(upper(substr(description, 1, 1)), 'Y', 'Y', 'N', 'N', NULL),
                      NULL)) notify_warning,
           MAX(decode(upper(lookup_code),
                      c_notify_failure_code,
                      decode(upper(substr(description, 1, 1)), 'Y', 'Y', 'N', 'N', NULL),
                      NULL)) notify_failure,
           MAX(decode(upper(lookup_code),
                      c_attach_output_code,
                      decode(upper(substr(description, 1, 1)), 'Y', 'Y', 'N', 'N', NULL),
                      NULL)) attach_output,
           MAX(decode(upper(lookup_code),
                      c_attach_log_code,
                      decode(upper(substr(description, 1, 1)), 'Y', 'Y', 'N', 'N', NULL),
                      NULL)) attach_log
    INTO   l_from_email,
           l_to_email,
           l_cc_email,
           l_bcc_email,
           l_notify_success,
           l_notify_warning,
           l_notify_failure,
           l_attach_output,
           l_attach_log
    FROM   fnd_lookup_values_vl
    WHERE  lookup_type = p_email_aol_lookup_type.lookup_type
    AND    enabled_flag = 'Y'
    AND    trunc(SYSDATE) BETWEEN trunc(start_date_active) AND trunc(nvl(end_date_active, SYSDATE));

    IF debug_enabled
    THEN
      log_internal('Configuration:', p_copy_messages_to_output);
      log_internal(' ' || c_from_code || ' = ' || l_from_email, p_copy_messages_to_output);
      log_internal(' ' || c_to_code || ' = ' || l_to_email, p_copy_messages_to_output);
      log_internal(' ' || c_cc_code || ' = ' || l_cc_email, p_copy_messages_to_output);
      log_internal(' ' || c_bcc_code || ' = ' || l_bcc_email, p_copy_messages_to_output);
      log_internal(' ' || c_notify_success_code || ' = ' || l_notify_success, p_copy_messages_to_output);
      log_internal(' ' || c_notify_warning_code || ' = ' || l_notify_warning, p_copy_messages_to_output);
      log_internal(' ' || c_notify_failure_code || ' = ' || l_notify_failure, p_copy_messages_to_output);
      log_internal(' ' || c_attach_output_code || ' = ' || l_attach_output, p_copy_messages_to_output);
      log_internal(' ' || c_attach_log_code || ' = ' || l_attach_log, p_copy_messages_to_output);
    END IF;

    -- Verify essentials
    assert(p_condition => l_from_email IS NOT NULL,
           p_neg_condition_text => 'Unable to send email due to missing ' || c_from_code || ' Code or its Description',
           p_context => describe_aol_lookup_type(p_email_aol_lookup_type),
           p_copy_to_output => p_copy_messages_to_output);

    assert(p_condition => l_to_email IS NOT NULL,
           p_neg_condition_text => 'Unable to send email due to missing ' || c_to_code || ' Code or its Description',
           p_context => describe_aol_lookup_type(p_email_aol_lookup_type),
           p_copy_to_output => p_copy_messages_to_output);

    -- Produce warning for missing or misconfigured entries
    IF l_notify_success IS NULL
    THEN
      warn(p_message => 'Code ' || c_notify_success_code || ' is missing or does not have a value of either Y or N; assuming Y',
           p_copy_to_output => p_copy_messages_to_output);
      l_notify_success := 'Y';
    END IF;

    IF l_notify_warning IS NULL
    THEN
      warn(p_message => 'Code ' || c_notify_warning_code || ' is missing or does not have a value of either Y or N; assuming Y',
           p_copy_to_output => p_copy_messages_to_output);
      l_notify_warning := 'Y';
    END IF;

    IF l_notify_failure IS NULL
    THEN
      warn(p_message => 'Code ' || c_notify_failure_code || ' is missing or does not have a value of either Y or N; assuming Y',
           p_copy_to_output => p_copy_messages_to_output);
      l_notify_failure := 'Y';
    END IF;

    IF l_attach_output IS NULL
    THEN
      warn(p_message => 'Code ' || c_attach_output_code || ' is missing or does not have a value of either Y or N; assuming Y',
           p_copy_to_output => p_copy_messages_to_output);
      l_attach_output := 'Y';
    END IF;

    IF l_attach_log IS NULL
    THEN
      warn(p_message => 'Code ' || c_attach_log_code || ' is missing or does not have a value of either Y or N; assuming Y',
           p_copy_to_output => p_copy_messages_to_output);
      l_attach_log := 'Y';
    END IF;

    -- Should we send a message?
    CASE l_program_retcode
      WHEN c_retcode_success THEN
        IF l_notify_success = 'N'
        THEN
          info('Email is not being sent since program completion status = ' || retcode_hash(l_program_retcode));
          RETURN;
        END IF;

      WHEN c_retcode_warning THEN
        IF l_notify_warning = 'N'
        THEN
          info('Email is not being sent since program completion status = ' || retcode_hash(l_program_retcode));
          RETURN;
        END IF;

      WHEN c_retcode_failure THEN
        IF l_notify_failure = 'N'
        THEN
          info('Email is not being sent since program completion status = ' || retcode_hash(l_program_retcode));
          RETURN;
        END IF;
    END CASE;

    -- Collect our attachments
    IF l_attach_output = 'Y'
       AND g_utl_file_location_stdout IS NOT NULL
    THEN
      l_attachment_locations(l_attachment_locations.COUNT + 1) := filename_logical_to_physical(g_utl_file_location_stdout);
    END IF;

    IF l_attach_log = 'Y'
       AND g_utl_file_location_stderr IS NOT NULL
    THEN
      l_attachment_locations(l_attachment_locations.COUNT + 1) := filename_logical_to_physical(g_utl_file_location_stderr);
    END IF;

    IF p_attachment1 IS NOT NULL
    THEN
      l_attachment_locations(l_attachment_locations.COUNT + 1) := filename_logical_to_physical(p_attachment1);
    END IF;

    IF p_attachment2 IS NOT NULL
    THEN
      l_attachment_locations(l_attachment_locations.COUNT + 1) := filename_logical_to_physical(p_attachment2);
    END IF;

    IF p_attachment3 IS NOT NULL
    THEN
      l_attachment_locations(l_attachment_locations.COUNT + 1) := filename_logical_to_physical(p_attachment3);
    END IF;

    -- Do we have any attachments?
    IF l_attachment_locations.COUNT > 0
    THEN
      l_attachment_message := 'Please review attached file(s) for additional details.';
    END IF;

    -- Pad attachment list with NULLs
    WHILE l_attachment_locations.COUNT < 5
    LOOP
      l_attachment_locations(l_attachment_locations.COUNT + 1) := NULL;
    END LOOP;

    -- Format and print message in log
    l_message := 'Sending Email:' || chr(10);
    l_message := l_message || ' SMTP Server : ' || ttec_library.XX_TTEC_SMTP_SERVER || chr(10);
    l_message := l_message || ' From        : ' || l_from_email || chr(10);
    l_message := l_message || ' To          : ' || l_to_email || chr(10);
    IF l_cc_email IS NOT NULL
    THEN
      l_message := l_message || ' CC          : ' || l_cc_email || chr(10);
    END IF;
    IF l_bcc_email IS NOT NULL
    THEN
      l_message := l_message || ' BCC         : ' || l_bcc_email || chr(10);
    END IF;
    l_message := l_message || ' Subject     : ' || l_subject || chr(10);
    IF p_message IS NOT NULL
    THEN
      l_message := l_message || ' Message     : ' || show_value(p_message) || chr(10);
    END IF;
    l_message := l_message || ' Called from : ' || determine_caller(1) || chr(10);

    FOR i IN l_attachment_locations.FIRST .. l_attachment_locations.LAST
    LOOP
      IF l_attachment_locations(i) IS NOT NULL
      THEN
        l_message := l_message || ' Attachment ' || i || ': ' || show_value(l_attachment_locations(i), '') || chr(10);
      END IF;
    END LOOP;
    info(p_message => l_message, p_copy_to_output => p_copy_messages_to_output);

    -- Actual email delivery
    send_email(p_smtp_srvr => ttec_library.XX_TTEC_SMTP_SERVER, /* Rehosting project change for smtp */ --l_smtp_server,
               p_from_email => l_from_email,
               p_to_email => l_to_email,
               p_cc_email => l_cc_email,
               p_bcc_email => l_bcc_email,
               p_subject => l_subject,
               p_body_line1 => 'Site Name Profile : ' || show_value(get_sitename),
               p_body_line2 => 'Program Name: ' || show_value(l_program_name),
               p_body_line3 => 'Message: ' || show_value(p_value => p_message, p_alternate_text_when_null => ''),
               p_body_line4 => '[Sending PL/SQL code: ' || determine_caller(1) || ']',
               p_body_line5 => l_attachment_message,
               p_attachment1 => l_attachment_locations(1),
               p_attachment2 => l_attachment_locations(2),
               p_attachment3 => l_attachment_locations(3),
               p_attachment4 => l_attachment_locations(4),
               p_attachment5 => l_attachment_locations(5),
               p_status => l_email_status,
               p_mesg => l_email_mesg);

    -- Ensure SEND_EMAIL call was successful
    assert(p_condition => l_email_status = 0,
           p_neg_condition_text => 'Email delivery failed',
           p_context => show_value(l_email_mesg),
           p_copy_to_output => p_copy_messages_to_output);

  EXCEPTION
    WHEN OTHERS THEN
      raise_contextual_exception(p_sqlcode => SQLCODE,
                                 p_sqlerrm => SQLERRM,
                                 p_backtrace => dbms_utility.format_error_backtrace,
                                 p_context => 'sending email');

  END email_completion_status;

  ------------------------------------------------------------------------------
  -- Set Concurrent Manager Return Values
  ------------------------------------------------------------------------------
  PROCEDURE set_conc_manager_return_values
  (
    p_sqlcode IN NUMBER,
    p_sqlerrm IN VARCHAR2,
    p_program_name IN VARCHAR2,
    p_errbuf OUT VARCHAR2,
    p_retcode OUT t_retcode
  ) IS
    l_message t_log_line;
  BEGIN
    determine_errbuf_retcode(p_sqlcode => p_sqlcode,
                             p_sqlerrm => p_sqlerrm,
                             p_program_name => p_program_name,
                             p_program_status_message => l_message,
                             p_program_retcode => p_retcode);

    -- make sure we do not exceed maximum ERRBUF length concurrent manager can handle
    BEGIN
      IF length(p_errbuf) > c_errbuf_max_line_length
      THEN
        p_errbuf := substr(l_message, 1, c_errbuf_max_line_length - 3) || '...';
      ELSE
        p_errbuf := l_message;
      END IF;
    EXCEPTION
      WHEN OTHERS THEN
        -- in case c_errbuf_max_line_length was set too high for this environment
        raise_contextual_exception(p_sqlcode => SQLCODE,
                                   p_sqlerrm => SQLERRM,
                                   p_backtrace => dbms_utility.format_error_backtrace,
                                   p_context => 'Concurrent Manager Return Message could not be set; ' || c_errbuf_max_line_length ||
                                                ' may exceed maximum message length allowed');
    END;
    log(p_log_level => c_log_level_info,
        p_message => 'Set Concurrent Manager Completion Return Code to ' || show_value(p_retcode) || ' (' || retcode_hash(p_retcode) || ')',
        p_additional_depth => 1);
    log(p_log_level => c_log_level_info,
        p_message => 'Set Concurrent Manager Completion Text to ' || show_value(p_errbuf),
        p_additional_depth => 1);
  END set_conc_manager_return_values;

  ------------------------------------------------------------------------------
  -- Log Elapsed Time
  ------------------------------------------------------------------------------
  PROCEDURE log_elapsed_time
  (
    p_task IN t_task,
    p_additional_depth IN NUMBER DEFAULT 0
  ) IS
    l_elapsed_time             INTERVAL DAY(9) TO SECOND(2);
    l_elapsed_time_seconds     NUMBER;
    l_elapsed_cpu_time_seconds NUMBER;
    l_end_time_100ths          NUMBER;
    l_end_cpu_time_100ths      NUMBER;
    l_elaspsed_description     VARCHAR2(500);
  BEGIN
    l_end_time_100ths     := nvl(p_task.end_time_100ths, dbms_utility.get_time);
    l_end_cpu_time_100ths := nvl(p_task.end_cpu_time_100ths, dbms_utility.get_cpu_time);

    l_elapsed_time_seconds     := nvl((l_end_time_100ths - p_task.start_time_100ths) / 100, 0);
    l_elapsed_cpu_time_seconds := nvl((l_end_cpu_time_100ths - p_task.start_cpu_time_100ths) / 100, 0);
    l_elapsed_time             := numtodsinterval(l_elapsed_time_seconds, 'SECOND');

    l_elaspsed_description := show_value(l_elapsed_time) || ' (' || to_char(l_elapsed_cpu_time_seconds, 'FM999G990D00') ||
                              ' CPU Seconds)';

    IF NOT p_task.has_started
    THEN
      log(p_log_level => p_task.log_level,
          p_message => p_task.task_name || ' HAS NOT YET STARTED',
          p_copy_to_output => p_task.copy_to_output,
          p_additional_depth => 1);
    ELSIF NOT p_task.has_finished
    THEN
      log(p_log_level => p_task.log_level,
          p_message => p_task.task_name || ' has taken ' || l_elaspsed_description,
          p_copy_to_output => p_task.copy_to_output,
          p_additional_depth => 1);
    ELSE
      log(p_log_level => p_task.log_level,
          p_message => p_task.task_name || ' took ' || l_elaspsed_description,
          p_copy_to_output => p_task.copy_to_output,
          p_additional_depth => 1);
    END IF;
  END log_elapsed_time;

  ------------------------------------------------------------------------------
  -- Start a new Timed Task
  ------------------------------------------------------------------------------
  FUNCTION start_task
  (
    p_log_level IN t_log_level,
    p_task_name IN VARCHAR2,
    p_copy_to_output IN BOOLEAN,
