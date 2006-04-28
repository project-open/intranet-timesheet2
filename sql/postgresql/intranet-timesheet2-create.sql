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



-- Add the sum of timesheet hours cached here for reporting
-- to the im_projects table
--
alter table im_projects add reported_hours_cache float;



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



create or replace function inline_0 ()
returns integer as '
declare
	-- Menu IDs
	v_menu		   integer;	v_parent_menu	   integer;
	-- Groups
	v_employees	   integer;	v_accounting	   integer;
	v_senman	   integer;	v_customers	   integer;
	v_freelancers      integer;	v_proman	   integer;
	v_admins	   integer;
BEGIN
    select group_id into v_admins from groups where group_name = ''P/O Admins'';
    select group_id into v_senman from groups where group_name = ''Senior Managers'';
    select group_id into v_proman from groups where group_name = ''Project Managers'';
    select group_id into v_accounting from groups where group_name = ''Accounting'';
    select group_id into v_employees from groups where group_name = ''Employees'';
    select group_id into v_customers from groups where group_name = ''Customers'';
    select group_id into v_freelancers from groups where group_name = ''Freelancers'';

    select menu_id into v_parent_menu
    from im_menus where label=''main'';

    v_menu := im_menu__new (
	null,				-- p_menu_id
	''acs_object'',			-- object_type
	now(),				-- creation_date
	null,				-- creation_user
	null,				-- creation_ip
	null,				-- context_id
	''intranet-timesheet2'',	-- package_name
	''timesheet2_timesheet'',	-- label
	''Timesheet'',			-- name
	''/intranet-timesheet2/hours/index'', -- url
	73,				-- sort_order
	v_parent_menu,			-- parent_menu_id
	null				-- p_visible_tcl
    );

    PERFORM acs_permission__grant_permission(v_menu, v_admins, ''read'');
    PERFORM acs_permission__grant_permission(v_menu, v_senman, ''read'');
    PERFORM acs_permission__grant_permission(v_menu, v_proman, ''read'');
    PERFORM acs_permission__grant_permission(v_menu, v_accounting, ''read'');
    PERFORM acs_permission__grant_permission(v_menu, v_employees, ''read'');
    PERFORM acs_permission__grant_permission(v_menu, v_customers, ''read'');
    PERFORM acs_permission__grant_permission(v_menu, v_freelancers, ''read'');

    v_menu := im_menu__new (
	null,				-- p_menu_id
	''acs_object'',			-- object_type
	now(),				-- creation_date
	null,				-- creation_user
	null,				-- creation_ip
	null,				-- context_id
	''intranet-timesheet2'',	-- package_name
	''timesheet2_absences'',	-- label
	''Absences'',			-- name
	''/intranet-timesheet2/hours/index'', -- url
	74,				-- sort_order
	v_parent_menu,			-- parent_menu_id
	null				-- p_visible_tcl
    );

    PERFORM acs_permission__grant_permission(v_menu, v_admins, ''read'');
    PERFORM acs_permission__grant_permission(v_menu, v_senman, ''read'');
    PERFORM acs_permission__grant_permission(v_menu, v_proman, ''read'');
    PERFORM acs_permission__grant_permission(v_menu, v_accounting, ''read'');
    PERFORM acs_permission__grant_permission(v_menu, v_employees, ''read'');
    PERFORM acs_permission__grant_permission(v_menu, v_customers, ''read'');
    PERFORM acs_permission__grant_permission(v_menu, v_freelancers, ''read'');
    return 0;
end;' language 'plpgsql';
select inline_0 ();
drop function inline_0 ();






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

