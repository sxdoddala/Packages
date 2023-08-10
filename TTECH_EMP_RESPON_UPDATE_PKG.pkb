create or replace PACKAGE BODY      TTECH_EMP_RESPON_UPDATE_PKG
AS
/********************************************************************************
* Name        : TECH_EMP_RESPON_UPDATE_PKG
* Author      : Amir Aslam
* Date        : 07-JUL-2015
* Description : THis Packae will END DTE the CEMp Respon
*
* Modifications History:
*
* Modified By       Date         Description
* --------------    -----------  -----------------------------------------------
  Amir Aslam       10-Aug-2015    Remove the Start date
  Amir Aslam       01-Dec-2015    Logic for Contengent Worker and Not End dating if it's already done.
  1.0	IXPRAVEEN(ARGANO)  18-july-2023		R12.2 Upgrade Remediation
********************************************************************************/
PROCEDURE EMP_RESPON_END_DATE (
            errbuf              OUT VARCHAR2,
            retcode             OUT NUMBER
            )
IS

Cursor c_disable
IS
        select  *
        --from    cust.ttech_emp_respon_update teru		-- Commented code by IXPRAVEEN-ARGANO,18-july-2023
        from    apps.ttech_emp_respon_update teru       --  code Added by IXPRAVEEN-ARGANO,   18-july-2023
        WHERE   teru.status = 'NEW'
        and     ( end_date IS NULL OR end_date >= SYSDATE );



    l_error      varchar2(4000);
    l_rec_count number := 0;
    p_type      varchar2(100);
    go_main     exception;
    l_user_id           number;
    l_responsibility_id number;
    l_application_id    number;
    l_security_group_id number;
    l_start_date        date;
    l_end_date          date;
    l_load_id           number;

BEGIN

    Fnd_File.PUT_LINE(Fnd_File.log,'***********************************************:  ' );
    Fnd_File.PUT_LINE(Fnd_File.log,' The Employee Responsibility Update:  ' );
    Fnd_File.PUT_LINE(Fnd_File.log,'***********************************************:  ' );



        BEGIN


            BEGIN

            l_load_id := NULL;
            -- Generate the Run ID.
            select  nvl(max(run_id)+1,1)
            into    l_load_id
            --from    cust.ttech_emp_respon_update_arch;		-- Commented code by IXPRAVEEN-ARGANO,18-july-2023
            from    apps.ttech_emp_respon_update_arch;          --  code Added by IXPRAVEEN-ARGANO,   18-july-2023
            EXCEPTION WHEN OTHERS THEN
                fnd_file.put_line(fnd_file.log,' Not able to genrate the Load Id '|| sqlerrm);
            END;


            BEGIN
            --insert into cust.ttech_emp_respon_update (employee_number , Respon_name , security_group_name , status , created_by , creation_date , last_update_date, last_update_by ,end_date )		-- Commented code by IXPRAVEEN-ARGANO,18-july-2023
            insert into apps.ttech_emp_respon_update (employee_number , Respon_name , security_group_name , status , created_by , creation_date , last_update_date, last_update_by ,end_date )          --  code Added by IXPRAVEEN-ARGANO,   18-july-2023
            select employee_number , Respon_name , security_group_name , 'NEW' , fnd_profile.value('USER_ID') ,SYSDATE ,  SYSDATE , fnd_profile.value('USER_ID')  ,end_date
            --from   cust.ttech_emp_respon_update_ext;			-- Commented code by IXPRAVEEN-ARGANO,18-july-2023
            from   apps.ttech_emp_respon_update_ext;            --  code Added by IXPRAVEEN-ARGANO,   18-july-2023

            fnd_file.put_line(fnd_file.log,' Data Loaded from EXT table to Temp table '|| sqlerrm);
            EXCEPTION WHEN OTHERS THEN
                fnd_file.put_line(fnd_file.log,' Not able to load data from EXT table to Temp table '|| sqlerrm);
            END;


            --update cust.ttech_emp_respon_update		-- Commented code by IXPRAVEEN-ARGANO,18-july-2023
            update apps.ttech_emp_respon_update         --  code Added by IXPRAVEEN-ARGANO,   18-july-2023
            set SECURITY_GROUP_NAME = replace (replace (SECURITY_GROUP_NAME, CHR (13), ''), CHR (10), '')
            ,   RESPON_NAME = replace (replace (RESPON_NAME, CHR (13), ''), CHR (10), '')
            ,   EMPLOYEE_NUMBER = replace (replace (EMPLOYEE_NUMBER, CHR (13), ''), CHR (10), '')
            ,   END_DATE = replace (replace (END_DATE, CHR (13), ''), CHR (10), '')
            ,   run_id          = l_load_id
            where status = 'NEW';

            COMMIT;


            fnd_file.put_line(fnd_file.log,' *************************** Start of the INTERFACE Program.  *************************** ' );

            FOR c_disable_rec IN c_disable
            LOOP
            l_rec_count := l_rec_count+1;
            l_user_id           := NULL;
            l_responsibility_id := NULL;
            l_application_id    := NULL;
            l_security_group_id := NULL;
            l_error             := NULL;

            IF c_disable_rec.employee_number IS NOT NULL
               and c_disable_rec.Respon_name IS NOT NULL
            THEN

            fnd_file.put_line(fnd_file.log,' ****************  Processing  ****************  '|| c_disable_rec.employee_number );

                -- Get the USER detail
                l_user_id := NULL;
                BEGIN
                    select  user_id
                    into    l_user_id
                    from    per_people_f ppf
                            , fnd_user fu
                    --where   ppf.employee_number = trim(c_disable_rec.employee_number)
                    where   nvl(NPW_NUMBER,ppf.employee_number) = trim(c_disable_rec.employee_number)
                    and     ppf.person_id = fu.employee_id
                    and     SYSDATE between effective_Start_date and effective_end_date;
                EXCEPTION WHEN OTHERS THEN
                    l_error := l_error || ' Not able to get USER detail for Employee '|| c_disable_rec.employee_number;
                    fnd_file.put_line(fnd_file.log,' Not able to get USER detail for Employee '|| c_disable_rec.employee_number);
                END;

                -- Get the  Responsibility detail.
                l_responsibility_id :=  NULL;
                l_application_id    :=  NULL;
                BEGIN
                    select  responsibility_id , application_id
                    into    l_responsibility_id , l_application_id
                    from    fnd_responsibility_vl
                    where   upper(responsibility_name) = trim(upper(c_disable_rec.Respon_name))
                    and     ( end_date IS NULL OR end_date > SYSDATE );
                EXCEPTION WHEN OTHERS THEN
                    l_error :=  l_error || ' Not able to get the Respon Detail for the Respon '|| c_disable_rec.employee_number;
                    fnd_file.put_line(fnd_file.log,' Not able to get the Respon Detail for the Respon '|| c_disable_rec.Respon_name);
                END;

                IF c_disable_rec.security_group_name is NOT NULL
                THEN

                    -- Get the  Security Group
                    l_security_group_id := NULL;
                    BEGIN
                        select  security_group_id
                        into    l_security_group_id
                        from    fnd_security_groups_vl
                        where   trim(upper(security_group_name)) = rtrim(ltrim(upper(c_disable_rec.security_group_name)));
                    EXCEPTION WHEN OTHERS THEN
                        l_error :=  l_error || ' Not able to get the Security Group name for the SEC GROUP NAME '|| c_disable_rec.security_group_name;
                        fnd_file.put_line(fnd_file.log,' Not able to get the Security Group name for the SEC GROUP NAME '|| c_disable_rec.security_group_name);
                    END;
                ELSE
                    l_security_group_id := 0;
                END IF;

                    l_start_date := NULL;
                    l_end_date   := NULL;
                    BEGIN
                    select  start_date  , end_date
                    into    l_start_date , l_end_date
                    from    FND_USER_RESP_GROUPS_DIRECT
                    where   user_id = l_user_id
                    and     responsibility_id = l_responsibility_id
                    and     security_group_id = l_security_group_id;
                    EXCEPTION WHEN OTHERS THEN
                        l_error :=  l_error || ' Not able to get the Start date for User ID '|| l_user_id || ' and respon ID  ' || l_responsibility_id;
                        fnd_file.put_line(fnd_file.log,' Not able to get the Start date for USer '|| l_user_id || ' and respon ID  ' || l_responsibility_id );
                    END;



                IF l_user_id is NOT NULL
                   and  l_responsibility_id  is NOT NULL
                   and  l_application_id     is NOT NULL
                   and  l_security_group_id  is NOT NULL
                   and ( l_end_date is NULL OR l_end_date >= SYSDATE )
                THEN
                    BEGIN
                        fnd_user_resp_groups_api.update_assignment(user_id                       => l_user_id               --  464161  -- p_rec.user_id
                                                                  ,responsibility_id             => l_responsibility_id     --  1005576  -- 1012570 -- p_get.responsibility_id
                                                                  ,responsibility_application_id => l_application_id        --  800       -- 222     -- p_get.application_id
                                                                  ,security_group_id             => l_security_group_id     --  89        -- 0
                                                                  ,start_date                    => nvl(l_start_date,SYSDATE)  --NULL --SYSDATE
                                                                  ,end_date                      => nvl(c_disable_rec.end_date,SYSDATE)
                                                                  ,description                   => 'Access denied via Oracle Recertification ');

                        fnd_file.put_line(fnd_file.log,'Success ' || sqlerrm);
                    EXCEPTION WHEN OTHERS THEN
                        fnd_file.put_line(fnd_file.log,'in the excep'|| sqlerrm);
                        l_error :=  l_error || sqlerrm;
                    END;

                ELSE
                        l_error :=  l_error || ' Either USERID, ResponID or APPLN ID is missing  Or RESP is already END DATEED for this Employee: '|| c_disable_rec.employee_number || '  . The End date for this Respon is:' || l_end_date;
                        fnd_file.put_line(fnd_file.log,' Either USERID, ResponID or APPLN ID is missing  Or RESP is already END DATEed for this Employee: ' || c_disable_rec.employee_number || '  . The End date for this Respon is:' || l_end_date);

                END IF;


            ELSE
                    l_error :=  l_error || ' Please Check, The Employee Number OR Respon is NULL ' || c_disable_rec.employee_number;
                    fnd_file.put_line(fnd_file.log,'Please Check, The Employee Number OR Respon is NULL ' );

            END IF;

                IF l_error is NOT NULL THEN

                 --IF c_disable_rec.status <> 'PROCESSED'
                 --THEN
                    --update cust.ttech_emp_respon_update		-- Commented code by IXPRAVEEN-ARGANO,18-july-2023
                    update apps.ttech_emp_respon_update         --  code Added by IXPRAVEEN-ARGANO,   18-july-2023
                    set    status = 'ERROR',
                    error_message = l_error
                    where  employee_number = c_disable_rec.employee_number
                    and RESPON_NAME        = c_disable_rec.RESPON_NAME
                    and    status = 'NEW';
                    --and    status <> 'PROCESSED';
                -- END IF;
                ELSE
                    --update cust.ttech_emp_respon_update				-- Commented code by IXPRAVEEN-ARGANO,18-july-2023
                    update apps.ttech_emp_respon_update                 --  code Added by IXPRAVEEN-ARGANO,   18-july-2023
                    set    status           = 'PROCESSED'
                    where  employee_number  = c_disable_rec.employee_number
                    and    RESPON_NAME      = c_disable_rec.RESPON_NAME
                    and    status           = 'NEW';

                END IF;



            END LOOP;
            COMMIT;


            Fnd_File.PUT_LINE(Fnd_File.log,' *************************** Archiving the data and Deleting from the Table. *************************** ' );

            -- Archiving the data and Deleting
            --insert into cust.ttech_emp_respon_update_arch select * from  cust.ttech_emp_respon_update;		-- Commented code by IXPRAVEEN-ARGANO,18-july-2023
            insert into apps.ttech_emp_respon_update_arch select * from  apps.ttech_emp_respon_update;          --  code Added by IXPRAVEEN-ARGANO,   18-july-2023

            --delete from cust.ttech_emp_respon_update;		-- Commented code by IXPRAVEEN-ARGANO,18-july-2023
            delete from apps.ttech_emp_respon_update;       --  code Added by IXPRAVEEN-ARGANO,   18-july-2023
            COMMIT;

            Fnd_File.PUT_LINE(Fnd_File.log,' *************************** End of the EMPLOYEE RESPON Program. *************************** ' );

        EXCEPTION WHEN OTHERS THEN
                NULL;
        END;


EXCEPTION WHEN OTHERS THEN
             Fnd_File.put_line(Fnd_File.log,' In the final exception:  ' || sqlerrm );
END;


END TTECH_EMP_RESPON_UPDATE_PKG;
/
show errors;
/