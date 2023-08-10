create or replace PACKAGE BODY      TTECH_USER_RESPON_UPDATE_PKG
AS
/********************************************************************************
* Name        : TTECH_USER_RESPON_UPDATE_PKG
* Author      : Hema C
* Date        : 25-OCT-2017
* Description : This Package will End Date current Responsibility assigned to user
				and create new responsibility to user.
* Modifications History:
*
* Modified By       Date         Description
* --------------    -----------  -----------------------------------------------
********************************************************************************/

PROCEDURE EMP_RESPON_END_INS_DATE (
            errbuf              OUT VARCHAR2,
            retcode             OUT NUMBER
            )
IS

Cursor c_update
IS
        select  *
        from    cust.ttech_user_respon_update tur
        WHERE   status = 'NEW'
		and     action = 'UPDATE'
		and     exists (select 1 from apps.fnd_responsibility_vl fv
		                        where fv.responsibility_name = tur.responsibility_name
								  and (fv.end_date IS NULL OR fv.end_date >= SYSDATE))
		and     exists (select 1 from apps.fnd_user fu
		                        where fu.user_name = tur.user_name
								  and (fu.end_date IS NULL OR fu.end_date >= SYSDATE ))
        and     ( end_date IS NULL OR end_date >= SYSDATE );

Cursor c_create
IS
        select  *
        from    cust.ttech_user_respon_update tur1
        WHERE   status = 'NEW'
		and     action = 'CREATE'
		and     exists (select 1 from apps.fnd_responsibility_vl fv
		                        where fv.responsibility_name = tur1.responsibility_name
								  and (fv.end_date IS NULL OR fv.end_date >= SYSDATE))
		and     exists (select 1 from apps.fnd_user fu
		                        where fu.user_name = tur1.user_name
								  and (fu.end_date IS NULL OR fu.end_date >= SYSDATE ))
        and     ( end_date IS NULL OR end_date >= SYSDATE );


-- Cursors for retrieving error log
Cursor c_update_err
IS
        select  *
        from    cust.ttech_user_respon_update
        WHERE   status = 'ERROR'
		and     action = 'UPDATE'
        and     ( end_date IS NULL OR end_date >= SYSDATE );

-- Cursors for retrieving error log
Cursor c_create_err
IS
        select  *
        from    cust.ttech_user_respon_update
        WHERE   status = 'ERROR'
		and     action = 'CREATE'
        and     ( end_date IS NULL OR end_date >= SYSDATE );



	ln_err_count number;
	ln_err_count1 number;
	--ln_rec_count number := 0;
	ln_tot_rec number;
	ln_tot_rec1 number;
    l_error      varchar2(4000);
	l_error1      varchar2(1000);
	l_rec_count number;
	l_rec_count1 number;
    p_type      varchar2(100);
    go_main     exception;
    l_user_id           number;
    l_responsibility_id number;
    l_application_id    number;
    l_security_group_id number;
	l_start_date        date;
    l_end_date          date;
    l_load_id           number;
	l_resp_count        number;
	duplicate_responsibility EXCEPTION;
	PRAGMA EXCEPTION_INIT(duplicate_responsibility
                       ,-20001);

BEGIN

retcode := 0;
errbuf := 'Successfully Completed';

    Fnd_File.PUT_LINE(Fnd_File.log,'***********************************************:  ' );
    Fnd_File.PUT_LINE(Fnd_File.log,' The Employee Responsibility Update:  ' );
    Fnd_File.PUT_LINE(Fnd_File.log,'***********************************************:  ' );



        BEGIN


            BEGIN

            l_load_id := NULL;
            -- Generate the Run ID.
            select  nvl(max(run_id)+1,1)
            into    l_load_id
            from    cust.ttech_user_respon_update_arch;
            EXCEPTION WHEN OTHERS THEN
				fnd_file.put_line(fnd_file.log,' Not able to generate the Load Id '|| sqlerrm);
            END;


            BEGIN
            insert into cust.ttech_user_respon_update (user_name , responsibility_name , security_group_name , action, status , created_by , creation_date , last_update_date, last_update_by ,end_date )
            select user_name , responsibility_name , security_group_name , action, 'NEW' , fnd_profile.value('USER_ID') ,SYSDATE ,  SYSDATE , fnd_profile.value('USER_ID')  ,end_date
            from   cust.ttec_user_respon_data_ext;

            fnd_file.put_line(fnd_file.log,' Data Loaded from EXT table to Temp table '|| sqlerrm);
            EXCEPTION WHEN OTHERS THEN
				fnd_file.put_line(fnd_file.log,' Not able to load data from EXT table to Temp table '|| sqlerrm);
            END;


            update cust.ttech_user_respon_update
            set RESPONSIBILITY_NAME = replace (replace (RESPONSIBILITY_NAME, CHR (13), ''), CHR (10), '')
            ,   SECURITY_GROUP_NAME = replace (replace (SECURITY_GROUP_NAME, CHR (13), ''), CHR (10), '')
			,   ACTION = replace (replace (ACTION, CHR (13), ''), CHR (10), '')
			,   USER_NAME = replace (replace (USER_NAME, CHR (13), ''), CHR (10), '')
            ,   END_DATE = replace (replace (END_DATE, CHR (13), ''), CHR (10), '')
            ,   run_id          = l_load_id
            where status = 'NEW';

            COMMIT;


            fnd_file.put_line(fnd_file.log,' *************************** Start of the INTERFACE Program.  *************************** ' );

		BEGIN
			l_rec_count := 0;
			ln_err_count := 0;
			ln_tot_rec := 0;

            FOR c_update_rec IN c_update
            LOOP
			l_user_id           := NULL;
            l_responsibility_id := NULL;
            l_application_id    := NULL;
            l_security_group_id := NULL;
            l_error             := NULL;

			BEGIN
			IF c_update_rec.USER_NAME IS NOT NULL
               and c_update_rec.responsibility_name IS NOT NULL
            THEN

            fnd_file.put_line(fnd_file.log,' ****************  Processing  ****************  '|| c_update_rec.USER_NAME );

                -- Get the USER detail
                l_user_id := NULL;
                BEGIN
                    select  user_id
                    into    l_user_id
                    from    per_people_f ppf
                            , fnd_user fu
                    --where   ppf.employee_number = trim(c_disable_rec.employee_number)
                    where   fu.user_name = trim(c_update_rec.USER_NAME)
                    and     ppf.person_id = fu.employee_id
                    and     SYSDATE between effective_Start_date and effective_end_date;
                EXCEPTION WHEN OTHERS THEN
					ln_err_count := ln_err_count + 1;
                    l_error := l_error || ' Not able to get USER detail for Employee '|| c_update_rec.USER_NAME;
                  --  fnd_file.put_line(fnd_file.log,' Not able to get USER detail for Employee '|| c_update_rec.USER_NAME);
                END;

                -- Get the  Responsibility detail.
                l_responsibility_id :=  NULL;
                l_application_id    :=  NULL;
                BEGIN
                    select  responsibility_id , application_id
                    into    l_responsibility_id , l_application_id
                    from    fnd_responsibility_vl
                    where   upper(responsibility_name) = trim(upper(c_update_rec.responsibility_name))
                    and     ( end_date IS NULL OR end_date > SYSDATE );
                EXCEPTION WHEN OTHERS THEN
					ln_err_count := ln_err_count + 1;
                    l_error :=  l_error || ' Not able to get the Respon Detail for the Respon '|| c_update_rec.responsibility_name;
                --    fnd_file.put_line(fnd_file.log,' Not able to get the Respon Detail for the Respon '|| c_update_rec.responsibility_name);
                END;

                IF c_update_rec.security_group_name is NOT NULL
                THEN

                    -- Get the  Security Group
                    l_security_group_id := NULL;
                    BEGIN
                        select  security_group_id
                        into    l_security_group_id
                        from    fnd_security_groups_vl
                        where   trim(upper(security_group_name)) = rtrim(ltrim(upper(c_update_rec.security_group_name)));
                    EXCEPTION WHEN OTHERS THEN
						ln_err_count := ln_err_count + 1;
                        l_error :=  l_error || ' Not able to get the Security Group name for the SEC GROUP NAME '|| c_update_rec.security_group_name;
                   --     fnd_file.put_line(fnd_file.log,' Not able to get the Security Group name for the SEC GROUP NAME '|| c_update_rec.security_group_name);
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
						ln_err_count := ln_err_count + 1;
                        l_error :=  l_error || ' Not able to get the Start date for User ID '|| l_user_id || ' and respon ID  ' || l_responsibility_id;
                    --    fnd_file.put_line(fnd_file.log,' Not able to get the Start date for USer '|| l_user_id || ' and respon ID  ' || l_responsibility_id );
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
                                                                  ,end_date                      => nvl(c_update_rec.end_date,SYSDATE)
                                                                  ,description                   => 'Access denied via Oracle Safepass ');

                        fnd_file.put_line(fnd_file.log,'Success ' || sqlerrm);
                    EXCEPTION WHEN OTHERS THEN
						ln_err_count := ln_err_count + 1;
                        --fnd_file.put_line(fnd_file.log,'in the excep'|| sqlerrm);
                        l_error :=  l_error || sqlerrm;

					update cust.ttech_user_respon_update
						 set    status = 'ERROR',
								error_message = l_error
						where  USER_NAME = c_update_rec.USER_NAME
						and responsibility_name = c_update_rec.responsibility_name
						and action = 'CREATE'
						and status = 'NEW';

                    END;

                ELSE
				ln_err_count := ln_err_count + 1;
                        l_error :=  l_error || ' Either USERID, ResponID or APPLN ID is missing  Or RESP is already END DATEED for this Employee: '|| c_update_rec.USER_NAME || '  . The End date for this Respon is:' || l_end_date;
                     --   fnd_file.put_line(fnd_file.log,' Either USERID, ResponID or APPLN ID is missing  Or RESP is already END DATEed for this Employee: ' || c_update_rec.USER_NAME || '  . The End date for this Respon is:' || l_end_date);


                END IF;


            ELSE
			ln_err_count := ln_err_count + 1;
                    l_error :=  l_error || ' Please Check, The Employee Number OR Respon is NULL ' || c_update_rec.USER_NAME;
                 --   fnd_file.put_line(fnd_file.log,'Please Check, The Employee Number OR Respon is NULL ' );


            END IF;

                IF l_error is NOT NULL THEN

                 --IF c_update_rec.status <> 'PROCESSED'
                 --THEN
                    update cust.ttech_user_respon_update
                    set    status = 'ERROR',
                    error_message = l_error
                    where  USER_NAME = c_update_rec.USER_NAME
                    and responsibility_name        = c_update_rec.responsibility_name
					and l_error not like '%FND_USER_RESP_GROUPS_API%'
					and action = 'UPDATE'
                    and    status = 'NEW';
                    --and    status <> 'PROCESSED';
                -- END IF;
                ELSE
                    update cust.ttech_user_respon_update
                    set    status           = 'PROCESSED'
                    where  USER_NAME  = c_update_rec.USER_NAME
                    and    responsibility_name      = c_update_rec.responsibility_name
					and action = 'UPDATE'
                    and    status  = 'NEW';

                END IF;
			END;

			l_rec_count := l_rec_count+1;

			END LOOP;
            COMMIT;

			Begin

			select count(1) into ln_err_count from cust.ttech_user_respon_update
			where status = 'ERROR'
			and run_id = l_load_id
			and action = 'UPDATE';

			Exception when others then
			  ln_err_count :=0;
			end;

			if ln_err_count > 0 then
			retcode := 1;
			--fnd_file.put_line(fnd_file.output,'Unsuccessfull Records Count, please verify log file;; '||','||ln_err_count);
			fnd_file.put_line(fnd_file.output,'Please verify log file for Unsuccessfull Records for Action: UPDATE: '||','||ln_err_count);
			end if;

			Begin
				 FOR c_update_err_rec IN c_update_err
					LOOP
			    fnd_file.put_line(fnd_file.log,'Error:'||c_update_err_rec.user_name||','||c_update_err_rec.responsibility_name
				||','||c_update_err_rec.security_group_name||','||c_update_err_rec.action||','||c_update_err_rec.error_message);
				fnd_file.put_line(fnd_file.log,'=====================================================================================================================');
					End Loop;
			End;

			Begin
				Select count(1) into ln_tot_rec
				FROM cust.ttech_user_respon_update turu1
				where action = 'UPDATE'
				and run_id = l_load_id;

				Exception when others then
				ln_tot_rec := 0;
			end;

				if ln_tot_rec >0 then

				ln_tot_rec := ln_tot_rec - nvl(ln_err_count,0);
				fnd_file.put_line(fnd_file.output,'Sucessfull Records Count for Action: UPDATE'||','||ln_tot_rec);
				end if;
				Exception when others then
				retcode :=2;
				errbuf := SQLERRM;

		 END;

			-- Enable valid responsibilites for user.
		 BEGIN
			l_rec_count1 := 0;
			ln_err_count1 := 0;
			ln_tot_rec1 := 0;

			FOR c_create_rec IN c_create
            LOOP
			l_user_id           := NULL;
            l_responsibility_id := NULL;
            l_application_id    := NULL;
            l_security_group_id := NULL;
            l_error             := NULL;

			BEGIN
			IF c_create_rec.USER_NAME IS NOT NULL
               and c_create_rec.responsibility_name IS NOT NULL
            THEN

            fnd_file.put_line(fnd_file.log,' ****************  Processing  ****************  '|| c_create_rec.USER_NAME );

                -- Get the USER detail
                l_user_id := NULL;
                BEGIN
                    select  user_id
                    into    l_user_id
                    from    per_people_f ppf
                            , fnd_user fu
                    --where   ppf.employee_number = trim(c_create_rec.employee_number)
                    where   fu.user_name = trim(c_create_rec.USER_NAME)
                    and     ppf.person_id = fu.employee_id
                    and     SYSDATE between effective_Start_date and effective_end_date;
                EXCEPTION WHEN OTHERS THEN
					ln_err_count1 := ln_err_count1 + 1;
				--	fnd_file.put_line(fnd_file.log,'Test : USer Details ->'||ln_err_count1);
                    l_error1 := l_error1 || ' Not able to get USER detail for Employee '|| c_create_rec.USER_NAME;
                --    fnd_file.put_line(fnd_file.log,' Not able to get USER detail for Employee '|| c_create_rec.USER_NAME);
                END;

                -- Get the  Responsibility detail.
                l_responsibility_id :=  NULL;
                l_application_id    :=  NULL;
                BEGIN
                    select  responsibility_id , application_id
                    into    l_responsibility_id , l_application_id
                    from    fnd_responsibility_vl
                    where   upper(responsibility_name) = trim(upper(c_create_rec.responsibility_name))
                    and     ( end_date IS NULL OR end_date > SYSDATE );
                EXCEPTION WHEN OTHERS THEN
					ln_err_count1 := ln_err_count1 + 1;
				--	fnd_file.put_line(fnd_file.log,'Test : Responsibility Detail ->'||ln_err_count1);
                    l_error1 :=  l_error1 || ' Not able to get the Respon Detail for the Respon '|| c_create_rec.responsibility_name;
                --    fnd_file.put_line(fnd_file.log,' Not able to get the Respon Detail for the Respon '|| c_create_rec.responsibility_name);
				l_responsibility_id :=  0;
                l_application_id    :=  0;
                END;



                IF c_create_rec.security_group_name is NOT NULL
                THEN

                    -- Get the  Security Group
                    l_security_group_id := NULL;
                    BEGIN
                        select  security_group_id
                        into    l_security_group_id
                        from    fnd_security_groups_vl
                        where   trim(upper(security_group_name)) = rtrim(ltrim(upper(c_create_rec.security_group_name)));
                    EXCEPTION WHEN OTHERS THEN
						ln_err_count1 := ln_err_count1 + 1;

                        l_error1 :=  l_error1 || ' Not able to get the Security Group name for the SEC GROUP NAME '|| c_create_rec.security_group_name;
                      --  fnd_file.put_line(fnd_file.log,' Not able to get the Security Group name for the SEC GROUP NAME '|| c_create_rec.security_group_name);
                    END;
                ELSE
                    l_security_group_id := 0;
                END IF;

			/*	-- Check whether responsibility already assigned to user
				l_resp_count : = null;
				BEGIN
                    select  count(1)
                     into l_resp_count
                    from    apps.FND_USER_RESP_GROUPS_DIRECT furgd
                    where furgd.responsibility_id = l_responsibility_id
					and furgd.user_id = l_user_id
					and furgd.SECURITY_GROUP_ID = l_security_group_id;

                --EXCEPTION WHEN OTHERS THEN
				if l_resp_count > 0 then
					EXCEPTION WHEN OTHERS THEN
					ln_err_count1 := ln_err_count1 + 1;
				--	fnd_file.put_line(fnd_file.log,'Responsibility all ready assigned to user ->'||ln_err_count1);
                    l_error1 :=  l_error1 || ' Responsibility all ready assigned to user'|| c_create_rec.responsibility_name;
                --    fnd_file.put_line(fnd_file.log,' Responsibility all ready assigned to user '|| c_create_rec.responsibility_name);
					END;
				else
					l_resp_count := 0;
				end if;
                END;
				*/

                IF l_user_id is NOT NULL
                   and  l_responsibility_id  is NOT NULL
                   and  l_application_id     is NOT NULL
                   and  l_security_group_id  is NOT NULL
				 --  and 	l_resp_count = 0

                THEN
                    BEGIN
                        fnd_user_resp_groups_api.insert_assignment(user_id                       => l_user_id               --  464161  -- p_rec.user_id
                                                                  ,responsibility_id             => l_responsibility_id     --  1005576  -- 1012570 -- p_get.responsibility_id
                                                                  ,responsibility_application_id => l_application_id        --  800       -- 222     -- p_get.application_id
                                                                  ,security_group_id             => l_security_group_id     --  89        -- 0
                                                                  ,start_date                    => TRUNC(SYSDATE) -1
                                                                  ,end_date                      => NULL
                                                                  ,description                   => 'Access Given via Oracle Safepass ');

                        fnd_file.put_line(fnd_file.log,'Success ' || sqlerrm);

					EXCEPTION
						WHEN duplicate_responsibility THEN
							fnd_user_resp_groups_api.update_assignment (user_id  => l_user_id
                                                  ,responsibility_id             => l_responsibility_id
                                                  ,responsibility_application_id => l_application_id
                                                  ,security_group_id             => l_security_group_id
                                                  ,start_date                    => TRUNC(SYSDATE) - 1
                                                  ,end_date                      => NULL
                                                  ,description                   => 'Access Reinstated via via Oracle Safepass');

						WHEN OTHERS THEN
						ln_err_count1 := ln_err_count1 + 1;
					  --  fnd_file.put_line(fnd_file.log,'in the excep'|| sqlerrm);
                        l_error1 :=  l_error1 || sqlerrm;

						update cust.ttech_user_respon_update
						 set    status = 'ERROR',
								error_message = l_error1
						where  USER_NAME = c_create_rec.USER_NAME
						and responsibility_name = c_create_rec.responsibility_name
						and action = 'CREATE'
						and status = 'NEW';

						COMMIT;
					--	fnd_file.put_line(fnd_file.log,'Test : After the API ->'||ln_err_count1);

                    END;

                ELSE
                        ln_err_count1 := ln_err_count1 + 1;
					--	fnd_file.put_line(fnd_file.log,'Test : USer Id is Null ->'||ln_err_count);
						l_error1 :=  l_error1 || ' Either USERID, ResponID or APPLN ID is missing  Or RESP is already END DATEED for this Employee: '|| c_create_rec.USER_NAME || '  . The End date for this Respon is:' || l_end_date;
                 --       fnd_file.put_line(fnd_file.log,' Either USERID, ResponID or APPLN ID is missing  Or RESP is already END DATEed for this Employee: ' || c_create_rec.USER_NAME || '  . The End date for this Respon is:' || l_end_date);

                END IF;


            ELSE
					ln_err_count1 := ln_err_count1 + 1;
			  --   fnd_file.put_line(fnd_file.log,'Test : Emp number or Respon is null ->'||ln_err_count);
                    l_error1 :=  l_error1 || ' Please Check, The Employee Number OR Respon is NULL ' || c_create_rec.USER_NAME;
               --     fnd_file.put_line(fnd_file.log,'Please Check, The Employee Number OR Respon is NULL ' );


            END IF;

                IF l_error1 is NOT NULL THEN
				--	fnd_file.put_line(fnd_file.log,'Please Check, before updating error ' );
                 --IF c_disable_rec.status <> 'PROCESSED'
                 --THEN
                    update cust.ttech_user_respon_update
                    set    status = 'ERROR',
                    error_message = l_error1
                    where  USER_NAME = c_create_rec.USER_NAME
                    and responsibility_name        = c_create_rec.responsibility_name
					and l_error1 not like '%FND_USER_RESP_GROUPS_API%'
					and action = 'CREATE'
                    and status = 'NEW';

				--	and run_id = l_load_id;
                    --and    status <> 'PROCESSED';
                -- END IF;
                ELSE
                    update cust.ttech_user_respon_update
                    set  status           = 'PROCESSED'
                    where USER_NAME  = c_create_rec.USER_NAME
                    and  responsibility_name      = c_create_rec.responsibility_name
					and action = 'CREATE'
                    and  status = 'NEW';

				--	and run_id = l_load_id;
					--fnd_file.put_line(fnd_file.log,'Please Check, after updating processed ' );
                END IF;
			END;

			l_rec_count1 := l_rec_count1 +1;

			END LOOP;
            COMMIT;

			Begin

			select count(1) into ln_err_count1 from cust.ttech_user_respon_update
			where status = 'ERROR'
			and run_id = l_load_id
			and action = 'CREATE';

			Exception when others then
			  ln_err_count1 :=0;
			end;
			if ln_err_count1 > 0 then
			retcode := 1;
			--fnd_file.put_line(fnd_file.output,'Unsuccessfull Records Count, please verify log file;; '||','||ln_err_count);
			fnd_file.put_line(fnd_file.output,'Please verify log file for Unsuccessfull Records for Action: CREATE '||','||ln_err_count1);
			end if;

			Begin
				 FOR c_create_err_rec IN c_create_err
					LOOP
			    fnd_file.put_line(fnd_file.log,'Error:'||c_create_err_rec.user_name||','||c_create_err_rec.responsibility_name
				||','||c_create_err_rec.security_group_name||','||c_create_err_rec.action||','||c_create_err_rec.error_message);
				fnd_file.put_line(fnd_file.log,'=====================================================================================================================');
					End Loop;
			End;

			Begin
				Select count(1) into ln_tot_rec1
				FROM cust.ttech_user_respon_update turu
				where action = 'CREATE'
				and run_id = l_load_id;

				Exception when others then
				ln_tot_rec1 := 0;
			end;

				if ln_tot_rec1 >0 then

				ln_tot_rec1 := ln_tot_rec1 - nvl(ln_err_count1,0);
				fnd_file.put_line(fnd_file.output,'Sucessfull Records Count for Action: CREATE'||','||ln_tot_rec1);
				end if;
				Exception when others then
				retcode :=2;
				errbuf := SQLERRM;

		END;


            Fnd_File.PUT_LINE(Fnd_File.log,' *************************** Archiving the data and Deleting from the Table. *************************** ' );

            -- Archiving the data and Deleting
            insert into cust.ttech_user_respon_update_arch select * from  cust.ttech_user_respon_update;

            delete from cust.ttech_user_respon_update;
            COMMIT;

            Fnd_File.PUT_LINE(Fnd_File.log,' *************************** End of the EMPLOYEE RESPON Program. *************************** ' );

        EXCEPTION WHEN OTHERS THEN
                NULL;
        END;


EXCEPTION WHEN OTHERS THEN
             Fnd_File.put_line(Fnd_File.log,' In the final exception:  ' || sqlerrm );
END EMP_RESPON_END_INS_DATE;

END TTECH_USER_RESPON_UPDATE_PKG;