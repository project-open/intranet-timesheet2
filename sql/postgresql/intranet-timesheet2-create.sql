-- /packages/intranet-timesheet2/sql/postgres/intranet-timesheet2-create.sql
--
-- Copyright (C) 1999-2006 various parties
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
	user_id			integer 
				constraint im_hours_user_id_nn
				not null 
				constraint im_hours_user_id_fk
				references users,
	project_id		integer 
				constraint im_hours_project_id_nn
				not null 
				constraint im_hours_project_id_fk
				references im_projects,
	day			timestamptz,
	hours			numeric(5,2),
				-- ArsDigita/ACS billing system - log prices with hours
	billing_rate		numeric(5,2),
	billing_currency	char(3)
				constraint im_hours_billing_currency_fk
				references currency_codes(iso),
	note			varchar(4000)
);

alter table im_hours add primary key (user_id, project_id, day);
create index im_hours_project_id_idx on im_hours(project_id);
create index im_hours_user_id_idx on im_hours(user_id);
create index im_hours_day_idx on im_hours(day);



------------------------------------------------------
-- Permissions and Privileges
--

-- add_hours actually is more of an obligation then a privilege...
select acs_privilege__create_privilege('add_hours','Add Hours','Add Hours');
select acs_privilege__add_child('admin', 'add_hours');


-- Everybody is able to see his own hours, so view_hours doesn't
-- make much sense...
select acs_privilege__create_privilege('view_hours_all','View Hours All','View Hours All');
select acs_privilege__add_child('admin', 'view_hours_all');


select im_priv_create('add_hours', 'Accounting');
select im_priv_create('add_hours', 'Employees');
select im_priv_create('add_hours', 'P/O Admins');
select im_priv_create('add_hours', 'Project Managers');
select im_priv_create('add_hours', 'Sales');
select im_priv_create('add_hours', 'Senior Managers');

select im_priv_create('view_hours_all', 'Accounting');
select im_priv_create('view_hours_all', 'P/O Admins');
select im_priv_create('view_hours_all', 'Project Managers');
select im_priv_create('view_hours_all', 'Sales');
select im_priv_create('view_hours_all', 'Senior Managers');


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
        'im_timesheet_project_component $user_id $project_id ',
	'_ intranet-timesheet2.Timesheet'
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
        'im_timesheet_home_component $user_id',
	'intranet-timesheet2.Timesheet'
    );

\i intranet-absences-create.sql
\i ../common/intranet-timesheet-common.sql
\i ../common/intranet-timesheet-backup.sql

