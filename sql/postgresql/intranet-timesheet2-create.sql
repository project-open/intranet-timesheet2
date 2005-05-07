-- /packages/intranet-timesheet2/sql/oracle/intranet-timesheet-create.sql
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

------------------------------------------------------------
-- Hours
--
-- We record logged hours of both project and client related work
--

create table im_hours (
	user_id			integer not null 
				constraint im_hours_user_id_fk
				references users,
	project_id		integer not null 
				constraint im_hours_project_id_fk
				references im_projects,
	day			timestamptz,
	hours			numeric(5,2),
				-- ArsDigita/ACS billing system
	billing_rate		numeric(5,2),
	billing_currency	char(3)
				constraint im_hours_billing_currency_fk
				references currency_codes(iso),
				-- P/O billing system - leave prices to price list
	material_id		integer
				constraint im_hours_material_fk
				references im_materials,
	note			varchar(4000),
	primary key(user_id, project_id, day)
);

create index im_hours_project_id_idx on im_hours(project_id);
create index im_hours_user_id_idx on im_hours(user_id);

-- add_absences makes it possible to restrict the absence registering to internal stuff
select acs_privilege__create_privilege('add_absences','Add Absences','Add Absences');
select acs_privilege__add_child('admin', 'add_absences');


-- view_absences_all restricts possibility to see absences of others
select acs_privilege__create_privilege('view_absences_all','View Absences All','View Absences All');
select acs_privilege__add_child('admin', 'view_absences_all');


-- add_hours actually is more of an obligation then a privilege...
select acs_privilege__create_privilege('add_hours','Add Hours','Add Hours');
select acs_privilege__add_child('admin', 'add_hours');


-- Everybody is able to see his own hours, so view_hours doesn't
-- make much sense...
select acs_privilege__create_privilege('view_hours_all','View Hours All','View Hours All');
 select acs_privilege__add_child('admin', 'view_hours_all');



------------------------------------------------------
-- Add Absences
---

select im_priv_create('add_absences',        'Accounting');
select im_priv_create('add_absences',        'Employees');
select im_priv_create('add_absences',        'Freelancers');
select im_priv_create('add_absences',        'P/O Admins');
select im_priv_create('add_absences',        'Project Managers');
select im_priv_create('add_absences',        'Sales');
select im_priv_create('add_absences',        'Senior Managers');


------------------------------------------------------
-- View Absences
---

select im_priv_create('view_absences_all',        'Accounting');
select im_priv_create('view_absences_all',        'Employees');
select im_priv_create('view_absences_all',        'Freelancers');
select im_priv_create('view_absences_all',        'P/O Admins');
select im_priv_create('view_absences_all',        'Project Managers');
select im_priv_create('view_absences_all',        'Sales');
select im_priv_create('view_absences_all',        'Senior Managers');


------------------------------------------------------
-- Add Hours
---

select im_priv_create('add_hours',        'Accounting');
select im_priv_create('add_hours',        'Employees');
select im_priv_create('add_hours',        'P/O Admins');
select im_priv_create('add_hours',        'Project Managers');
select im_priv_create('add_hours',        'Sales');
select im_priv_create('add_hours',        'Senior Managers');

------------------------------------------------------
-- View Hours All
--

select im_priv_create('view_hours_all',        'Accounting');
select im_priv_create('view_hours_all',        'P/O Admins');
select im_priv_create('view_hours_all',        'Project Managers');
select im_priv_create('view_hours_all',        'Sales');
select im_priv_create('view_hours_all',        'Senior Managers');



------------------------------------------------------
-- Absences
--

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
        receive_email_p         char(1) default 't'
                                constraint im_user_absences_email_const
                                check (receive_email_p in ('t','f')),
        last_modified           date,
        absence_type_id		integer
                                references im_categories
                                constraint im_user_absences_type_const not null
);
alter table im_user_absences add constraint owner_and_start_date_unique unique (owner_id,start_date);

create index im_user_absences_user_id_idx on im_user_absences(owner_id);
create index im_user_absences_dates_idx on im_user_absences(start_date, end_date);
create index im_user_absences_type_idx on im_user_absences(absence_type_id);

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


select im_component_plugin__new (
	null,					-- plugin_id
	'acs_object',				-- object_type
	now(),					-- creation_date
	null,					-- creation_user
	null,					-- creattion_ip
	null,					-- context_id

        'Project Timesheet Component',		-- plugin_name
        'intranet-timesheet',			-- package_name
        'right',				-- location
	'/intranet/projects/view',		-- page_url
        null,					-- view_name
        50,					-- sort_order
        'im_table_with_title "[_ intranet-timesheet2.Timesheet]" [im_timesheet_project_component $user_id $project_id ]'
    );

select im_component_plugin__new (
	null,					-- plugin_id
	'acs_object',				-- object_type
	now(),					-- creation_date
	null,					-- creation_user
	null,					-- creattion_ip
	null,					-- context_id

        'Home Timesheet Component',		-- plugin_name
        'intranet-timesheet',			-- package_name
        'right',				-- location
	'/intranet/index',			-- page_url
        null,					-- view_name
        80,					-- sort_order
        'im_table_with_title "[_ intranet-timesheet2.Timesheet]" [im_timesheet_home_component $user_id]'
    );

\i ../common/intranet-timesheet-common.sql
\i ../common/intranet-timesheet-backup.sql

