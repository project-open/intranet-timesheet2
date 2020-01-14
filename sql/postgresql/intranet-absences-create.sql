-- /packages/intranet-timesheet2/sql/postgresql/intranet-absences-create.sql
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

insert into acs_object_type_tables (object_type,table_name,id_column)
values ('im_user_absence', 'im_user_absences', 'absence_id');


-- Setup status and type columns for im_user_absences
update acs_object_types set 
	status_type_table = 'im_user_absences',
	status_column = 'absence_status_id', 
	type_column = 'absence_type_id' 
where object_type = 'im_user_absence';

-- Define how to link to Absence pages from the Forum or the
-- Search Engine
insert into im_biz_object_urls (object_type, url_type, url) values (
'im_user_absence','view','/intranet-timesheet2/absences/new?form_mode=display&absence_id=');
insert into im_biz_object_urls (object_type, url_type, url) values (
'im_user_absence','edit','/intranet-timesheet2/absences/new?absence_id=');


------------------------------------------------------
-- Absences Table
--
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
	group_id		integer
				constraint im_user_absences_group_fk
				references groups,
        start_date              timestamptz
                                constraint im_user_absences_start_const not null,
        end_date                timestamptz
                                constraint im_user_absences_end_const not null,
	duration_days		numeric(12,1) default 1.0
				constraint im_user_absences_duration_days_nn not null,
        description             text,
        contact_info            text,
	-- should this user receive email during the absence?
        receive_email_p         char(1) default 't'
                                constraint im_user_absences_email_const
                                check (receive_email_p in ('t','f')),
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
				not null,
	vacation_replacement_id	integer
				constraint im_user_absences_vacation_replacement_fk
				references parties
);

-- Unique constraint to avoid that you can add two identical absences
alter table im_user_absences 
add constraint owner_and_start_date_unique unique (owner_id, absence_type_id, start_date);

-- Incices to speed up frequent queries
create index im_user_absences_user_id_idx on im_user_absences(owner_id);
create index im_user_absences_dates_idx on im_user_absences(start_date, end_date);
create index im_user_absences_type_idx on im_user_absences(absence_type_id);


-- Check constraint to make sure that the owner_id isnt set accidentally
-- if the absence refers to a group.
-- alter table im_user_absences add constraint im_user_absences_group_ck 
-- check (not (group_id is not null and absence_type_id != 5005));



-----------------------------------------------------------
-- Create, Drop and Name PlPg/SQL functions
--
-- These functions represent creator/destructor
-- functions for the OpenACS object system.

create or replace function im_user_absence__name(integer)
returns varchar as '
DECLARE
	p_absence_id		alias for $1;
	v_name			varchar;
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

-- add_absences makes it possible to restrict the absence registering to internal stuff
SELECT acs_privilege__create_privilege('add_absences','Add Absences','Add Absences');
SELECT acs_privilege__add_child('admin', 'add_absences');

-- view_absences_all restricts possibility to see absences of others
SELECT acs_privilege__create_privilege('view_absences_all','View Absences All','View Absences All');
SELECT acs_privilege__add_child('admin', 'view_absences_all');
select acs_privilege__create_privilege('add_absences_all','Add absences all','Add absences all');
select acs_privilege__add_child('create', 'add_absences_all');

-- add_absences_for_group allows to define absences for groups of users
SELECT acs_privilege__create_privilege('add_absences_for_group','Add Absences For Group','Add Absences For Group');
SELECT acs_privilege__add_child('admin', 'add_absences_for_group');

-- add absences for direct reports?
select acs_privilege__create_privilege('view_absences_direct_reports','View Absences Direct Reports','View Absences Direct Reports');
select acs_privilege__add_child('view', 'view_absences_direct_reports');
select acs_privilege__create_privilege('add_hours_direct_reports','Add hours for direct reports','');
select acs_privilege__add_child('admin', 'add_hours_direct_reports');



-- Set default permissions per group
SELECT im_priv_create('add_absences', 'Employees');
SELECT im_priv_create('add_absences', 'Freelancers');

SELECT im_priv_create('view_absences_all', 'Employees');

-- Allow the Accounting guys, HR dept and Senior managers to add absences for all users
SELECT im_priv_create('add_absences_for_group', 'Accounting');
SELECT im_priv_create('add_absences_for_group', 'HR Managers');
SELECT im_priv_create('add_absences_for_group', 'Senior Managers');


-- Privilege that determines if a user can override the Workflow
-- Can a user confirm his own vacation requests?
SELECT acs_privilege__create_privilege('edit_absence_status','Edit Absence Status','Edit Absence Status');
SELECT acs_privilege__add_child('admin', 'edit_absence_status');

SELECT im_priv_create('edit_absence_status', 'Accounting');
SELECT im_priv_create('edit_absence_status', 'P/O Admins');
SELECT im_priv_create('edit_absence_status', 'Project Managers');
SELECT im_priv_create('edit_absence_status', 'Senior Managers');



-----------------------------------------------------------
-- Type and Status
--
-- 5000 - 5099	Intranet Absence types
-- 16000-16999  Intranet Absences (1000)
-- 16000-16099	Intranet Absence Status
-- 16100-16999	reserved

SELECT im_category_new (16000, 'Active', 'Intranet Absence Status');
SELECT im_category_new (16002, 'Deleted', 'Intranet Absence Status');
SELECT im_category_new (16004, 'Requested', 'Intranet Absence Status');
SELECT im_category_new (16006, 'Rejected', 'Intranet Absence Status');

SELECT im_category_new (5000, 'Vacation', 'Intranet Absence Type');
SELECT im_category_new (5001, 'Personal', 'Intranet Absence Type');
SELECT im_category_new (5002, 'Sick', 'Intranet Absence Type');
SELECT im_category_new (5003, 'Travel', 'Intranet Absence Type');
SELECT im_category_new (5004, 'Training', 'Intranet Absence Type');
SELECT im_category_new (5005, 'Bank Holiday', 'Intranet Absence Type');
SELECT im_category_new (5006, 'Overtime', 'Intranet Absence Type');
SELECT im_category_new (5007, 'Reduction in Working Hours', 'Intranet Absence Type'); 
SELECT im_category_new (5008, 'Weekend', 'Intranet Absence Type'); 


-- Set the default WF for each absence type
update im_categories set aux_string1 = 'vacation_approval_wf' where category_id = 5000;
update im_categories set aux_string1 = 'personal_approval_wf' where category_id = 5001;
update im_categories set aux_string1 = 'sick_approval_wf' where category_id = 5002;
update im_categories set aux_string1 = 'travel_approval_wf' where category_id = 5003;
update im_categories set aux_string1 = 'training_approval_wf' where category_id = 5004;
update im_categories set aux_string1 = 'bank_holiday_approval_wf' where category_id = 5005;


update im_categories set aux_string2 = '99CCFF' where category_id = 5000;
update im_categories set aux_string2 = 'CCFFCC' where category_id = 5001;
update im_categories set aux_string2 = 'CC9999' where category_id = 5002;
update im_categories set aux_string2 = 'CC99FF' where category_id = 5003;
update im_categories set aux_string2 = 'FFCC99' where category_id = 5004;
update im_categories set aux_string2 = 'CCCCCC' where category_id = 5005;
update im_categories set aux_string2 = 'FF99CC' where category_id = 5006;
update im_categories set aux_string2 = 'FF9999' where category_id = 5007;
update im_categories set aux_string2 = 'BBBBBB' where category_id = 5008;


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
create or replace function on_vacation_p (timestamptz) 
returns CHAR as $body$
DECLARE
	p_vacation_until alias for $1;
BEGIN
        IF (p_vacation_until is not null) AND (p_vacation_until >= now()) THEN
                RETURN 't';
        ELSE
                RETURN 'f';
        END IF;
END;$body$ language 'plpgsql';



-- ------------------------------------------------------
-- Workflow graph on Absence View Page
-- ------------------------------------------------------

SELECT  im_component_plugin__new (
	null,					-- plugin_id
	'im_component_plugin',			-- object_type
	now(),					-- creation_date
	null,					-- creation_user
	null,					-- creation_ip
	null,					-- context_id

	'Absence Workflow',			-- component_name
	'intranet-timesheet2',			-- package_name
	'right',				-- location
	'/intranet-timesheet2/absences/new',	-- page_url
	null,					-- view_name
	10,					-- sort_order
	'im_workflow_graph_component -object_id $absence_id'
);


-- ------------------------------------------------------
-- Journal on Absence View Page
-- ------------------------------------------------------

SELECT  im_component_plugin__new (
	null,					-- plugin_id
	'im_component_plugin',			-- object_type
	now(),					-- creation_date
	null,					-- creation_user
	null,					-- creation_ip
	null,					-- context_id

	'Absence Journal',			-- component_name
	'intranet-timesheet2',			-- package_name
	'bottom',				-- location
	'/intranet-timesheet2/absences/new',	-- page_url
	null,					-- view_name
	100,					-- sort_order
	'im_workflow_journal_component -object_id $absence_id'
);


-- Create a plugin for the Vacation Balance
SELECT im_component_plugin__new (
	null,				-- plugin_id
	'im_component_plugin',		-- object_type
	now(),				-- creation_date
	null,				-- creation_user
	null,				-- creation_ip
	null,				-- context_id
	'Vacation Balance',		-- plugin_name
	'intranet-timesheet2',		-- package_name
	'left',				-- location
	'/intranet/users/view',		-- page_url
	null,				-- view_name
	20,				-- sort_order
	'im_absence_vacation_balance_component -user_id_from_search $user_id'	-- component_tcl
);

-- The component itself does a more thorough check
SELECT acs_permission__grant_permission(
	(select plugin_id from im_component_plugins where plugin_name = 'Vacation Balance' and package_name = 'intranet-timesheet2'), 
	(select group_id from groups where group_name = 'Employees'),
	'read'
);




-- ------------------------------------------------------
-- Menus
-- ------------------------------------------------------

SELECT im_new_menu(
	'intranet-timesheet2',
	'timesheet2_absences_vacation',
	'New Vacation Absence',
	'/intranet-timesheet2/absences/new?absence_type_id=5000',
	10,
	'timesheet2_absences', 
	null
);
SELECT im_new_menu_perms('timesheet2_absences_vacation', 'Employees');

SELECT im_new_menu(
	'intranet-timesheet2',
	'timesheet2_absences_personal',
	'New Personal Absence',
	'/intranet-timesheet2/absences/new?absence_type_id=5001',
	20,
	'timesheet2_absences', 
	null
);
SELECT im_new_menu_perms('timesheet2_absences_personal', 'Employees');

SELECT im_new_menu(
	'intranet-timesheet2',
	'timesheet2_absences_sick',
	'New Sick Leave',
	'/intranet-timesheet2/absences/new?absence_type_id=5002',
	30,
	'timesheet2_absences', 
	null
);
SELECT im_new_menu_perms('timesheet2_absences_sick', 'Employees');

SELECT im_new_menu(
	'intranet-timesheet2',
	'timesheet2_absences_travel',
	'New Travel Absence',
	'/intranet-timesheet2/absences/new?absence_type_id=5003',
	40,
	'timesheet2_absences', 
	null
);
SELECT im_new_menu_perms('timesheet2_absences_travel', 'Employees');

SELECT im_new_menu(
	'intranet-timesheet2',
	'timesheet2_absences_bankholiday',
	'New Bank Holiday',
	'/intranet-timesheet2/absences/new?absence_type_id=5004',
	50,
	'timesheet2_absences', 
	null
);
SELECT im_new_menu_perms('timesheet2_absences_bankholiday', 'Employees');






create or replace function inline_0 ()
returns integer as '
declare
	v_menu		   integer;	
	v_parent_menu	   integer;
	v_employees	   integer;
	v_count		   integer;
BEGIN
    select group_id into v_employees from groups where group_name = ''Employees'';

    select count(*) into v_count from im_menus where label = ''reporting-timesheet-weekly-report'';
    IF v_count > 0 THEN return 0; END IF;

    select menu_id into v_parent_menu from im_menus where label=''reporting-timesheet'';

    v_menu := im_menu__new (
	null,				-- p_menu_id
	''im_component_plugin'',	-- object_type
	now(),				-- creation_date
	null,				-- creation_user
	null,				-- creation_ip
	null,				-- context_id
	''intranet-timesheet2'',	-- package_name
	''reporting-timesheet-weekly-report'',	-- label
	''Timesheet Weekly Report'',	-- name
	''/intranet-timesheet2/weekly_report?'', -- url
	77,				-- sort_order
	v_parent_menu,			-- parent_menu_id
	null				-- p_visible_tcl
    );

    PERFORM acs_permission__grant_permission(v_menu, v_employees, ''read'');

    return 0;
end;' language 'plpgsql';
select inline_0 ();
drop function inline_0 ();




-- ------------------------------------------------------
-- Add DynFields
-- ------------------------------------------------------
--
-- select im_dynfield_attribute__new (
-- 	null,				-- widget_id
-- 	'im_dynfield_attribute',	-- object_type
-- 	now(),				-- creation_date
-- 	null,				-- creation_user
-- 	null,				-- creation_ip	
-- 	null,				-- context_id
-- 
-- 	'im_user_absence',		-- attribute_object_type
-- 	'description',			-- attribute name
-- 	0,				-- min_n_values
-- 	1,				-- max_n_values
-- 	null,				-- default_value
-- 	'date',				-- ad_form_datatype
-- 	'#intranet-timesheet2.Description#',	-- pretty name
-- 	'#intranet-timesheet2.Description#',	-- pretty plural
-- 	'textarea_small',		-- widget_name
-- 	'f',				-- deprecated_p
-- 	't'				-- already_existed_p
-- );
-- 
-- update acs_attributes set sort_order = 50
-- where attribute_name = 'description' and object_type = 'im_user_absence';
-- 
-- 
-- Add DynFields
--
-- select im_dynfield_attribute__new (
-- 	null,				-- widget_id
-- 	'im_dynfield_attribute',	-- object_type
-- 	now(),				-- creation_date
-- 	null,				-- creation_user
-- 	null,				-- creation_ip	
-- 	null,				-- context_id
-- 
-- 	'im_user_absence',		-- attribute_object_type
-- 	'contact_info',			-- attribute name
-- 	0,				-- min_n_values
-- 	1,				-- max_n_values
-- 	null,				-- default_value
-- 	'date',				-- ad_form_datatype
-- 	'#intranet-timesheet2.Contact#',	-- pretty name
-- 	'#intranet-timesheet2.Contact#',	-- pretty plural
-- 	'textarea_small',		-- widget_name
-- 	'f',				-- deprecated_p
-- 	't'				-- already_existed_p
-- );
-- 
-- update acs_attributes set sort_order = 60
-- where attribute_name = 'contact_info' and object_type = 'im_user_absence';



SELECT im_dynfield_widget__new (
	null, 'im_dynfield_widget', now(), 0, '0.0.0.0', null,
	'absence_vacation_replacements', 'Absence Vacation Replacements', 'Absence Vacation Replacements',
	10007, 'integer', 'generic_sql', 'integer',
	'{custom {sql {
		select	p.person_id,
			im_name_from_user_id(p.person_id) as person_name
		from 
			persons p
		where
			p.person_id in (
				select	member_id
				from	group_distinct_member_map
				where	group_id in (
						select	group_id
						from	groups
						where	group_name = ''Employees''
					)
			)
		order by 
			lower(first_names), lower(last_name)
	}}}'
);

SELECT im_dynfield_attribute_new ('im_user_absence', 'vacation_replacement_id', 'Vacation Replacement', 'absence_vacation_replacements', 'integer', 'f');




create or replace function im_absences_get_absences_for_user(int4,date,date,int4) returns setof record as $body$
    declare
            v_user_id               ALIAS FOR $1;
            v_start_date            ALIAS FOR $2;
            v_end_date              ALIAS FOR $3;
            v_absence_type_id       ALIAS FOR $4;

            v_default_date_format   varchar(10) := 'YYYY-MM-DD';
            v_dow                   integer;
            v_date_found            date;
            v_sql_result            record;
            v_record                record;
            v_searchsql             text;

    begin
           FOR v_record IN
                    -- get user absences
                    select
			    a.absence_id,
                            a.start_date,
                            a.end_date,
                            a.absence_type_id
                    from
                            im_user_absences a
                    where
                            a.group_id is null and
                            a.owner_id = v_user_id and (
                                (
                                         -- start date of absence must be later than start date of period
                                         -- but not later than end_date of period we look at
                                         a.start_date::date >= v_start_date::date AND
                                         a.start_date::date <= v_end_date::date
                                ) OR
                                (
                                         -- start date of absence must be earler than start date of period
                                         -- ... and later than Start date of period
                                         a.end_date::date <= v_end_date::date AND
                                         a.end_date::date >= v_start_date::date
                                )
                           )
                   UNION
                      -- get all group absences
                        select
				i.absence_id,
                                i.start_date,
                                i.end_date,
                                i.absence_type_id
                        from (
                                select
                                        a.absence_id,
					a.start_date,
                                        a.end_date,
                                        a.absence_type_id,
                                        a.group_id
                                from
                                        im_user_absences a
                                where
                                        group_id is not null and (
                                        (
                                         -- start date of absence must be later than start date of period
                                         -- but not later than end_date of period we look at
                                         a.start_date::date >= v_start_date::date AND
                                         a.start_date::date <= v_end_date::date
                                        ) OR
                                        (
                                         a.end_date::date <= v_end_date::date AND
                                         a.end_date::date >= v_start_date::date
                                        )
                                        )
                       ) i
                where
                        acs_group__member_p(624, i.group_id, TRUE::boolean)
                LOOP
                    -- Enumeration over start/end date of period
                    v_searchsql = 'select
                                        im_day_enumerator as d,
                                        1 as absence_type_id,
					0 as absence_id
                                    from
                                        im_day_enumerator (''' || v_start_date || '''::date ,''' ||  v_end_date || '''::date +1)';

                    -- RAISE NOTICE 'im_absences_get_absences_for_user: v_searchsql= %', v_searchsql;

                    FOR v_sql_result IN EXECUTE v_searchsql
                    LOOP
                            -- Get date from seq
                            v_date_found := v_sql_result.d;
                            -- check for date
                            IF v_date_found::date >= v_record.start_date::date AND v_date_found::date <= v_record.end_date::date THEN
                                -- check for absence type
                                IF v_absence_type_id = NULL OR v_record.absence_type_id = v_record.absence_type_id THEN
                                        select into v_sql_result.absence_type_id v_record.absence_type_id;
					select into v_sql_result.absence_id v_record.absence_id;
                                        RETURN next v_sql_result;
                                END IF;
                            END IF;
                    END LOOP;
            END LOOP;
end;$body$ language 'plpgsql';



create or replace function im_absences_month_absence_duration_type (user_id integer, month integer, year integer, absence_type_id integer)
returns setof record as $BODY$
declare
        v_user_id               ALIAS FOR $1;
        v_month                 ALIAS FOR $2;
        v_year                  ALIAS FOR $3;
        v_absence_type_id       ALIAS FOR $4;

        v_default_date_format   varchar(10) := 'yyyy/mm/dd';
        v_dow                   integer;
        v_month_found           integer;
        v_sql_result            record;
        v_record                record;
        v_searchsql             text;
	v_sql           	text;
begin
    -- sql to get all absences 
    v_sql := $$select a.start_date, a.end_date, duration_days, absence_type_id from im_user_absences a where a.owner_id = $$;
    v_sql := v_sql || v_user_id; 
    v_sql := v_sql || $$ and ((date_part('month', a.start_date) = $$; 
    v_sql := v_sql || v_month; 
    v_sql := v_sql || $$ AND date_part('year', a.start_date) = $$;
    v_sql := v_sql || v_year;
    v_sql := v_sql || $$ ) OR (date_part('month', a.end_date) = $$;
    v_sql := v_sql || v_month;
    v_sql := v_sql || $$ AND date_part('year', a.end_date) = $$;
    v_sql := v_sql || v_year;
    v_sql := v_sql || $$ )) and a.absence_status_id in (16000, 16004)$$;

    -- Limit absence when absence_type_id is provided 
    IF      0 != v_absence_type_id THEN
            v_sql := v_sql || ' and a.absence_type_id = v_absence_type_id';
    END IF; 

    
        FOR v_record IN
        EXECUTE v_sql
        LOOP
        -- for each absence build sequence 
                v_searchsql := 'select 
                    im_day_enumerator as d,
                    ' || v_record.duration_days || ' as dd,
                    ' || v_record.absence_type_id || ' as ddd               
                from 
                    im_day_enumerator
                    (
                     to_date(''' || v_record.start_date || ''',''' || v_default_date_format || '''), 
                     to_date(''' || v_record.end_date || ''', ''' || v_default_date_format || ''') +1 
                     ) 
                ';

                FOR v_sql_result IN EXECUTE v_searchsql
                LOOP
		        -- Limit output to elements of month inquired for  
                        select into v_month_found date_part('month', v_sql_result.d);
                        IF v_month_found = v_month THEN
                	-- Limit output to weekdays only  
                                select into v_dow extract (dow from v_sql_result.d);
                                IF v_dow <> 0 AND v_dow <> 6 THEN
                                        return next v_sql_result;
                                END IF;
                        END IF;
                END LOOP;
        END LOOP;
end;$BODY$
language 'plpgsql';





CREATE OR REPLACE FUNCTION im_absences_get_absences_for_user_duration(integer, date, date, integer)
  RETURNS SETOF record AS
$BODY$
    -- Adds duration to im_absences_get_absences_for_user 
    declare
            v_user_id               ALIAS FOR $1;
            v_start_date            ALIAS FOR $2;
            v_end_date              ALIAS FOR $3;
            v_absence_type_id       ALIAS FOR $4;

            v_default_date_format   varchar(10) := 'YYYY-MM-DD';
            v_dow                   integer;
            v_date_found            date;
            v_sql_result            record;
            v_record                record;
            v_searchsql             text;

    begin
           FOR v_record IN
                    -- get user absences
                    select
                            a.absence_id,
                            a.start_date,
                            a.end_date,
                            a.absence_type_id,
                            a.duration_days
                    from
                            im_user_absences a
                    where
                            a.group_id is null and
                            a.owner_id = v_user_id and (
                                                (
                                                a.start_date::date between v_start_date::date and v_end_date::date::date OR
                                                a.end_date::date between v_start_date::date and v_end_date::date::date
                                                )
                                                OR
                                                (
                                                v_start_date::date between a.start_date::date and a.end_date::date OR
                                                v_end_date::date between a.start_date::date and a.end_date::date
                                                )
                           )
                   UNION
                      -- get all group absences
                        select
                                i.absence_id,
                                i.start_date,
                                i.end_date,
                                i.absence_type_id,
                                i.duration_days
                        from (
                                select
                                        a.absence_id,
                                        a.start_date,
                                        a.end_date,
                                        a.duration_days,
                                        a.absence_type_id,
                                        a.group_id
                                from
                                        im_user_absences a
                                where
                                        group_id is not null and (
                                                (
                                                a.start_date::date between v_start_date::date and v_end_date::date::date OR
                                                a.end_date::date between v_start_date::date and v_end_date::date::date
                                                )
                                                OR
                                                (
                                                v_start_date::date between a.start_date::date and a.end_date::date OR
                                                v_end_date::date between a.start_date::date and a.end_date::date
                                                )
                                        )
                       ) i
                       where
                                acs_group__member_p(v_user_id, i.group_id, TRUE::boolean)
                LOOP
                    -- Enumeration over start/end date of period
                    v_searchsql = 'select
                                        im_day_enumerator as d,
                                        1 as absence_type_id,
                                        0 as absence_id,
                                        0.00 as duration_days
                                    from
                                        im_day_enumerator (''' || v_start_date || '''::date ,''' ||  v_end_date || '''::date +1)';

                    -- RAISE NOTICE 'im_absences_get_absences_for_user: v_searchsql= %', v_searchsql;

                    FOR v_sql_result IN EXECUTE v_searchsql
                    LOOP
                            -- Get date from seq
                            v_date_found := v_sql_result.d;
                            -- check for date
                            IF v_date_found::date >= v_record.start_date::date AND v_date_found::date <= v_record.end_date::date THEN
                                -- check for absence type
                                IF v_absence_type_id = NULL OR v_record.absence_type_id = v_record.absence_type_id THEN
                                        select into v_sql_result.absence_type_id v_record.absence_type_id;
                                        select into v_sql_result.absence_id v_record.absence_id;
                                        IF v_record.duration_days >= 1.0 THEN
                                                select into v_sql_result.duration_days 1;
                                        ELSE 
                                                select into v_sql_result.duration_days v_record.duration_days::numeric;
                                        END IF;
                                        RETURN next v_sql_result;
                                END IF;
                            END IF;
                    END LOOP;
            END LOOP;
end;$BODY$ LANGUAGE plpgsql;





