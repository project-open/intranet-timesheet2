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


-----------------------------------------------------------
-- Create the object type

SELECT acs_object_type__create_type (
	'im_user_absence',		-- object_type
	'Absence',			-- pretty_name
	'Absences',			-- pretty_plural
	'acs_object',			-- supertype
	'im_user_absences',		-- table_name
	'absence_id',			-- id_column
	'intranet-timesheet2',		-- package_name
	'f',				-- abstract_p
	null,				-- type_extension_table
	'im_user_absence__name'		-- name_method
);


------------------------------------------------------
-- Absences Table
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
	                                primary key
					constraint im_user_absences_id_fk
					references acs_objects,

		absence_name		varchar(1000),

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

		-- Status and type for orderly objects...
	        absence_type_id		integer
	                                constraint im_user_absences_type_fk
	                                references im_categories
	                                constraint im_user_absences_type_nn
					not null,
	        absence_status_id	integer
	                                constraint im_user_absences_status_fk
	                                references im_categories
	                                constraint im_user_absences_type_nn 
					not null
	);
	alter table im_user_absences add constraint owner_and_start_date_unique unique (owner_id,start_date);
	
	create index im_user_absences_user_id_idx on im_user_absences(owner_id);
	create index im_user_absences_dates_idx on im_user_absences(start_date, end_date);
	create index im_user_absences_type_idx on im_user_absences(absence_type_id);
	
        return 0;
end;' language 'plpgsql';
select inline_0 ();
drop function inline_0 ();




-----------------------------------------------------------
-- Create, Drop and Name PlPg/SQL functions
--
-- These functions represent creator/destructor
-- functions for the OpenACS object system.


create or replace function im_user_absence__name(integer)
returns varchar as '
DECLARE
	p_absence_id		alias for $1;
	v_name			varchar(2000);
BEGIN
	select	absence_name into v_name
	from	im_user_absences
	where	absence_id = p_absence_id;

	-- compatibility fallback
	IF v_name is null THEN
		select	substring(description for 1900) into v_name
		from	im_user_absences
		where	absence_id = p_absence_id;
	END IF;

	return v_name;
end;' language 'plpgsql';


create or replace function im_user_absence__new (
	integer, varchar, timestamptz,
	integer, varchar, integer,
	varchar, integer, timestamptz, timestamptz,
	integer, integer, varchar, varchar
) returns integer as '
DECLARE
	p_absence_id		alias for $1;		-- absence_id  default null
	p_object_type   	alias for $2;		-- object_type default ''im_user_absence''
	p_creation_date 	alias for $3;		-- creation_date default now()
	p_creation_user 	alias for $4;		-- creation_user default null
	p_creation_ip   	alias for $5;		-- creation_ip default null
	p_context_id		alias for $6;		-- context_id default null

	p_absence_name		alias for $7;		-- absence_name
	p_owner_id		alias for $8;		-- owner_id
	p_start_date		alias for $9;
	p_end_date		alias for $10;

	p_absence_status_id	alias for $11;
	p_absence_type_id	alias for $12;
	p_description		alias for $13;
	p_contact_info		alias for $14;

	v_absence_id	integer;
BEGIN
	v_absence_id := acs_object__new (
		p_absence_id,		-- object_id
		p_object_type,		-- object_type
		p_creation_date,	-- creation_date
		p_creation_user,	-- creation_user
		p_creation_ip,		-- creation_ip
		p_context_id,		-- context_id
		''f''			-- security_inherit_p
	);

	insert into im_user_absences (
		absence_id, absence_name, 
		owner_id, start_date, end_date,
		absence_status_id, absence_type_id,
		description, contact_info
	) values (
		v_absence_id, p_absence_name, 
		p_owner_id, p_start_date, p_end_date,
		p_absence_status_id, p_absence_type_id,
		p_description, p_contact_info
	);

	return v_absence_id;
END;' language 'plpgsql';


create or replace function im_user_absence__delete(integer)
returns integer as '
DECLARE
	p_absence_id	alias for $1;
BEGIN
	-- Delete any data related to the object
	delete from im_user_absences
	where	absence_id = p_absence_id;

	-- Finally delete the object iself
	PERFORM acs_object__delete(p_absence_id);

	return 0;
end;' language 'plpgsql';




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





-----------------------------------------------------------
-- Type and Status
--
-- 5000 - 5099	Intranet Absence types
-- 16000-16999  Intranet Absences (1000)
-- 16000-16099	Intranet Absence Status
-- 16100-16999	reserved


create or replace function inline_0 ()
returns integer as '
declare
        v_count                 integer;
begin
        select count(*) into v_count
        from im_categories where category_id = 5000;
        if v_count > 0 then return 0; end if;

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


insert into im_categories(category_id, category, category_type) 
values (16000, 'Active', 'Intranet Absence Status');
insert into im_categories(category_id, category, category_type) 
values (16002, 'Deleted', 'Intranet Absence Status');
insert into im_categories(category_id, category, category_type) 
values (16004, 'Requested', 'Intranet Absence Status');



-----------------------------------------------------------
-- Create views for shortcut
--

create or replace view im_user_absence_status as
select	category_id as absence_status_id, category as absence_status
from	im_categories
where	category_type = 'Intranet Absence Status'
	and (enabled_p is null or enabled_p = 't');

create or replace view im_user_absence_types as
select	category_id as absence_type_id, category as absence_type
from	im_categories
where	category_type = 'Intranet Absencey Type'
	and (enabled_p is null or enabled_p = 't');




-----------------------------------------------------------
-- On vacation?

-- on_vacation_p refers to the vacation_until column of the users table
-- it does not care about user_vacations!
create or replace function on_vacation_p (timestamptz) returns CHAR as '
DECLARE
	p_vacation_until alias for $1;
BEGIN
        IF (p_vacation_until is not null) AND (p_vacation_until >= now()) THEN
                RETURN ''t'';
        ELSE
                RETURN ''f'';
        END IF;
END;' language 'plpgsql';


