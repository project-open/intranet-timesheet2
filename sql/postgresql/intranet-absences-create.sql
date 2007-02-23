-- /packages/intranet-timesheet2/sql/oracle/intranet-absences-create.sql
--
-- Copyright (C) 1999-2004 various parties
-- The code is based on ArsDigita ACS 3.4
--
-- This program is free software. You can redistribute it
-- and/or modify it under the terms of the GNU General
-- Public License as published by the Free Software Foundation;
-- either version 2 of the License, or (at your option)
-- any later version. This program is distributed in the
-- hope that it will be useful, but WITHOUT ANY WARRANTY;
-- without even the implied warranty of MERCHANTABILITY or
-- FITNESS FOR A PARTICULAR PURPOSE.
-- See the GNU General Public License for more details.
--
-- @author      unknown@arsdigita.com
-- @author      frank.bergmann@project-open.com


------------------------------------------------------
-- Absences
--


create or replace function inline_0 ()
returns integer as '
declare
        v_count                 integer;
begin
        select count(*) into v_count
        from user_tab_columns where table_name = ''IM_USER_ABSENCES'';
        if v_count > 0 then return 0; end if;


	create sequence im_user_absences_id_seq start 1;
	create table im_user_absences (
	        absence_id              integer
	                                constraint im_user_absences_pk
	                                primary key,
	        owner_id                integer
	                                constraint im_user_absences_user_fk
	                                references users,
	        start_date              timestamptz
	                                constraint im_user_absences_start_const not null,
	        end_date                timestamptz
	                                constraint im_user_absences_end_const not null,
	        description             varchar(4000),
	        contact_info            varchar(4000),
	        -- should this user receive email during the absence?
	        receive_email_p         char(1) default ''t''
	                                constraint im_user_absences_email_const
	                                check (receive_email_p in (''t'',''f'')),
	        last_modified           date,
	        absence_type_id		integer
	                                references im_categories
	                                constraint im_user_absences_type_const not null
	);
	alter table im_user_absences add constraint owner_and_start_date_unique unique (owner_id,start_date);
	
	create index im_user_absences_user_id_idx on im_user_absences(owner_id);
	create index im_user_absences_dates_idx on im_user_absences(start_date, end_date);
	create index im_user_absences_type_idx on im_user_absences(absence_type_id);
	
        return 0;
end;' language 'plpgsql';
select inline_0 ();
drop function inline_0 ();




------------------------------------------------------
-- Absences Permissions
--


create or replace function inline_0 ()
returns integer as '
declare
        v_count                 integer;
begin
        select count(*) into v_count
        from acs_privileges where privilege = ''add_absences'';
        if v_count > 0 then return 0; end if;


	-- add_absences makes it possible to restrict the absence registering to internal stuff
	select acs_privilege__create_privilege(''add_absences'',''Add Absences'',''Add Absences'');
	select acs_privilege__add_child(''admin'', ''add_absences'');
	
	-- view_absences_all restricts possibility to see absences of others
	select acs_privilege__create_privilege(''view_absences_all'',''View Absences All'',''View Absences All'');
	select acs_privilege__add_child(''admin'', ''view_absences_all'');
	
	
	select im_priv_create(''add_absences'', ''Accounting'');
	select im_priv_create(''add_absences'', ''Employees'');
	select im_priv_create(''add_absences'', ''Freelancers'');
	select im_priv_create(''add_absences'', ''P/O Admins'');
	select im_priv_create(''add_absences'', ''Project Managers'');
	select im_priv_create(''add_absences'', ''Sales'');
	select im_priv_create(''add_absences'', ''Senior Managers'');
	
	
	select im_priv_create(''view_absences_all'', ''Accounting'');
	select im_priv_create(''view_absences_all'', ''Employees'');
	select im_priv_create(''view_absences_all'', ''Freelancers'');
	select im_priv_create(''view_absences_all'', ''P/O Admins'');
	select im_priv_create(''view_absences_all'', ''Project Managers'');
	select im_priv_create(''view_absences_all'', ''Sales'');
	select im_priv_create(''view_absences_all'', ''Senior Managers'');

        return 0;
end;' language 'plpgsql';
select inline_0 ();
drop function inline_0 ();



create or replace function inline_0 ()
returns integer as '
declare
        v_count                 integer;
begin
        select count(*) into v_count
        from im_categories where category_id = 5000;
        if v_count > 0 then return 0; end if;


	-- 5000 - 5099 Absence types
	insert into im_categories ( CATEGORY_DESCRIPTION, ENABLED_P, CATEGORY_ID, CATEGORY, CATEGORY_TYPE) values
	('''', ''f'', ''5000'', ''Vacation'', ''Intranet Absence Type'');
	insert into im_categories ( CATEGORY_DESCRIPTION, ENABLED_P, CATEGORY_ID, CATEGORY, CATEGORY_TYPE) values
	('''', ''f'', ''5001'', ''Personal'', ''Intranet Absence Type'');
	insert into im_categories ( CATEGORY_DESCRIPTION, ENABLED_P, CATEGORY_ID, CATEGORY, CATEGORY_TYPE) values
	('''', ''f'', ''5002'', ''Sick'', ''Intranet Absence Type'');
	insert into im_categories ( CATEGORY_DESCRIPTION, ENABLED_P, CATEGORY_ID, CATEGORY, CATEGORY_TYPE) values
	('''', ''f'', ''5003'', ''Travel'', ''Intranet Absence Type'');

        return 0;
end;' language 'plpgsql';
select inline_0 ();
drop function inline_0 ();




-- on_vacation_p refers to the vacation_until column of the users table
-- it does not care about user_vacations!
create or replace function on_vacation_p (timestamptz) returns CHAR as '
DECLARE
	p_vacation_until alias for $1	-- vacation_until
BEGIN
        IF (p_vacation_until is not null) AND (p_vacation_until >= now()) THEN
                RETURN ''t'';
        ELSE
                RETURN ''f'';
        END IF;
END;' language 'plpgsql';

