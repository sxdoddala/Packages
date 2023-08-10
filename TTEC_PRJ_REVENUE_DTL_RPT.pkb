create or replace PACKAGE BODY      ttec_prj_revenue_dtl_rpt
AS
  /*
    -------------------------------------------------------------

    Program Name    : ttec_prj_revenue_dtl_rpt


    Created By      : Prachi Rajhans
    Date            : 18-NOV-2019f

    Modification Log:
    -----------------
    Developer             Date           Description

    Prachi R  1.0         05-DEC-2019    Created
    Rajesh    1.1         26-AUG-2020    Added Columns and Made OU Mandatory
    RXNETHI-ARGANO        18/MAY/2023    R12.2 Upgrade Remediation
    ------------------------------------------------------------------------------------------------------------------------------*/
  PROCEDURE main (
    errbuff                IN OUT NOCOPY    VARCHAR2
   ,retcode                IN OUT NOCOPY    NUMBER
  -- ,p_output_directory     IN               VARCHAR2
    ,p_organization_id      IN               hr_operating_units.organization_id%TYPE
   ,p_start_date           IN               VARCHAR2
   ,p_end_date             IN               VARCHAR2

  )
  IS
    CURSOR csr_prj_details (
      l_start_date         DATE
     ,l_end_date           DATE
     ,l_organization_id    hr_operating_units.organization_id%TYPE
    )
    IS
      SELECT   --c.event_id , b.project_id , pt.task_id ,
               b.segment1 project_number
              ,REGEXP_REPLACE (b.description, '           ', '') description
              ,b.org_id org_id
              ,hou.name operating_unit
              ,(select name from apps.gl_ledgers
              where ledger_id=hou.set_of_books_id) Ledger_Name  /*1.1*/
              ,pt.task_name task_name
              ,pt.attribute2 task_type
              ,pt.attribute1 task_client_code
              --,a.project_id project_id
      ,        b.segment1 project_id
              ,a.draft_revenue_num draft_revenue_num
              ,a.line_num line_num
              ,a.task_id task_id
              ,a.amount amount
              ,a.revenue_source revenue_source
              ,a.projfunc_currency_code projfunc_currency_code
              ,a.projfunc_revenue_amount projfunc_revenue_amount
              ,c.gl_period_name gl_period_name
              ,c.gl_date gl_date
              ,c.creation_date event_date
          /*
		  START R12.2 Upgrade Remediation
		  code commented by RXNETHI-ARGANO,18/05/23
		  FROM pa.pa_draft_revenue_items a
              ,pa.pa_projects_all b
              ,pa.pa_draft_revenues_all c
          */
		  --code added by RXNETHI-ARGANO,18/05/23
		  FROM apps.pa_draft_revenue_items a
              ,apps.pa_projects_all b
              ,apps.pa_draft_revenues_all c
		  --END R12.2 Upgrade Remediation
		      ,apps.pa_tasks pt
              ,hr_operating_units hou
         WHERE a.project_id = b.project_id
           AND a.project_id = c.project_id
           AND a.draft_revenue_num = c.draft_revenue_num
           --AND c.creation_date BETWEEN '01-OCT-2019' AND '31-DEC-2019'   --TO_DATE ('01-01-2017', 'mm-dd-yyyy')
           AND c.gl_date BETWEEN l_start_date AND l_end_date
           AND pt.task_id = a.task_id(+)
           AND b.org_id = hou.organization_id
           AND hou.organization_id = NVL(l_organization_id,hou.organization_id)  /*1.1*/
      ORDER BY b.segment1
              ,c.creation_date DESC;

    CURSOR c_host
    IS
      SELECT host_name
            ,instance_name
        FROM v$instance;

    v_text                VARCHAR (32765)                           DEFAULT '';
    v_file_extn           VARCHAR2 (200)                            DEFAULT '';
    v_time                VARCHAR2 (20);
    l_active_file         VARCHAR2 (200)                            DEFAULT '';
    v_file_type           UTL_FILE.FILE_TYPE;
    v_current_run_date    DATE;
    l_start_date          DATE;
    l_end_date            DATE;
    l_host_name           v$instance.host_name%TYPE;
    l_instance_name       v$instance.instance_name%TYPE;
    l_identifier          VARCHAR2 (100);
    l_error_step          VARCHAR2 (10);
    l_organization_id     hr_operating_units.organization_id%TYPE;
  BEGIN   /*Changes 2.3 added original hire date*/
    OPEN c_host;

    FETCH c_host
     INTO l_host_name
         ,l_instance_name;

    CLOSE c_host;

    IF l_host_name NOT IN (ttec_library.xx_ttec_prod_host_name)
    THEN
      l_identifier   := 'TTEC_test_PRDTL.';
    ELSE
      l_identifier   := 'TTEC_PRJ_DTL.';
    END IF;

    FND_FILE.PUT_LINE (FND_FILE.LOG, 'Host Name:');

    BEGIN
      SELECT '.csv'
            ,TO_CHAR (SYSDATE, 'yyyy-mm-dd hh24:mm:ss')
        INTO v_file_extn
            ,v_time
        FROM v$instance;
    EXCEPTION
      WHEN OTHERS
      THEN
        v_file_extn   := '.csv';
    END;

    l_active_file       := l_identifier || v_time || v_file_extn;
    FND_FILE.PUT_LINE (FND_FILE.LOG, 'FILE name:');
    --v_file_type         := UTL_FILE.FOPEN (p_output_directory, l_active_file, 'w', 32765);
    FND_FILE.PUT_LINE (FND_FILE.LOG, 'Opened the File:');
    l_start_date        := fnd_date.canonical_to_date (p_start_date);
    l_end_date          := fnd_date.canonical_to_date (p_end_date);
    l_organization_id   := p_organization_id;
    v_text              :=
      'PROJECT_NUMBER|DESCRIPTION|ORGANIZATION_ID|OPERATING_UNIT|LEDGER_NAME|TASK_NAME|TASK_TYPE|TASK_CLIENT_CODE|AMOUNT|PROJFUNC_CURR_CODE|PROJFUNC_REVENUE_AMT|GL_PERIOD_NAME|GL_DATE';
    FND_FILE.PUT_LINE (FND_FILE.OUTPUT, v_text);
    --UTL_FILE.PUT_LINE (v_file_type, v_text);

    FOR rec_prj_dtl IN csr_prj_details (l_start_date, l_end_date, l_organization_id)
    LOOP
      FND_FILE.PUT_LINE (FND_FILE.LOG, 'opened the cursor:');
      v_text   := '';
      v_text   := rec_prj_dtl.project_id ||
                  '|' ||
                  REGEXP_REPLACE(REPLACE(REPLACE(rec_prj_dtl.description,'	',''),CHR(10),''), '[^0-9A-Za-z)(-] ', '')||
                  '|' ||
                  REPLACE (rec_prj_dtl.org_id, '|', '') ||
                  '|' ||
                   REPLACE (rec_prj_dtl.operating_unit, '|', '') ||
                  '|' ||
                   REPLACE (rec_prj_dtl.Ledger_Name, '|', '') ||
                  '|' ||
                  REPLACE (rec_prj_dtl.task_name, '|', '') ||
                  '|' ||
                  REPLACE (rec_prj_dtl.task_type, '|', '') ||
                  '|' ||
                  REPLACE (rec_prj_dtl.task_client_code, '|', '') ||
                  '|' ||
                 -- REPLACE (rec_prj_dtl.project_id, '|', '') ||
                 -- '|' ||
                 -- REPLACE (rec_prj_dtl.draft_revenue_num, '|', '') ||
                 -- '|' ||
                 --  REPLACE (rec_prj_dtl.line_num, '|', '') ||
                 --  '|' ||
                 --  REPLACE (rec_prj_dtl.task_id, '|', '') ||
                 --  '|' ||
                  REPLACE (rec_prj_dtl.amount, '|', '') ||
                  '|' ||
                 --  REPLACE (rec_prj_dtl.revenue_source, '|', '') ||
                 --  '|' ||
                  REPLACE (rec_prj_dtl.projfunc_currency_code, '|', '') ||
                  '|' ||
                  REPLACE (rec_prj_dtl.projfunc_revenue_amount, '|', '') ||
                  '|' ||
                  REPLACE (rec_prj_dtl.gl_period_name, '|', '') ||
                  '|' ||
                  TO_CHAR (rec_prj_dtl.gl_date, 'DD-MON-RRRR');
      FND_FILE.PUT_LINE (FND_FILE.OUTPUT, v_text);
      --UTL_FILE.PUT_LINE (v_file_type, v_text);
    END LOOP;

    --UTL_FILE.FCLOSE (v_file_type);
  EXCEPTION
    WHEN OTHERS
    THEN
      UTL_FILE.FCLOSE (v_file_type);
      FND_FILE.PUT_LINE (FND_FILE.LOG, 'Error out of main loop main_proc -' || SQLERRM);
  END main;
END ttec_prj_revenue_dtl_rpt;
/
show errors;
/