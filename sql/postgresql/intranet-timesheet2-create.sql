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


-- specified how many units of what material are planned for
-- each project / subproject / task (all the same...)
--
create table im_timesheet_tasks (
	project_id		integer not null 
				constraint im_timesheet_tasks_project_fk
				references im_projects,
	material_id		integer
				constraint im_timesheet_tasks_material_fk
				references im_materials,
	uom_id			integer
				constraint im_timesheet_tasks_uom_fk
				references im_categories,
	planned_units		float,
	billable_units		float,
				-- sum of timesheet hours cached here for reporting
	reported_units_cache	float,
	description		varchar(4000),
	primary key(project_id, material_id)
);


---------------------------------------------------------
-- Timesheet Task Object Type

select acs_object_type__create_type (
	'im_timesheet task',		-- object_type
	'Timesheet Task',		-- pretty_name
	'Timesheet Tasks',		-- pretty_plural
	'acs_object',		-- supertype
	'im_timesheet tasks',		-- table_name
	'timesheet task_id',		-- id_column
	'intranet-timesheet task',	-- package_name
	'f',			-- abstract_p
	null,			-- type_extension_table
	'im_timesheet task.name'	-- name_method
    );



create or replace function im_timesheet task__new (
	integer,
	varchar,
	timestamptz,
	integer,
	varchar,
	integer,
	
	varchar,
	varchar,
	integer,
	integer,
	integer,
	varchar
    ) 
returns integer as '
declare
	p_timesheet task_id		alias for $1;		-- timesheet task_id default null
	p_object_type		alias for $2;		-- object_type default ''im_timesheet task''
	p_creation_date		alias for $3;		-- creation_date default now()
	p_creation_user		alias for $4;		-- creation_user
	p_creation_ip		alias for $5;		-- creation_ip default null
	p_context_id		alias for $6;		-- context_id default null

	p_timesheet task_name		alias for $7;	
	p_timesheet task_nr		alias for $8;	
	p_timesheet task_type_id	alias for $9;
	p_timesheet task_status_id	alias for $10;
	p_timesheet task_uom_id	alias for $11;
	p_description		alias for $12;

	v_timesheet task_id		integer;
    begin
 	v_timesheet task_id := acs_object__new (
                p_timesheet task_id,            -- object_id
                p_object_type,            -- object_type
                p_creation_date,          -- creation_date
                p_creation_user,          -- creation_user
                p_creation_ip,            -- creation_ip
                p_context_id,             -- context_id
                ''t''                     -- security_inherit_p
        );

	insert into im_timesheet tasks (
		timesheet task_id,
		timesheet task_name,
		timesheet task_nr,
		timesheet task_type_id,
		timesheet task_status_id,
		timesheet task_uom_id,
		description
	) values (
		p_timesheet task_id,
		p_timesheet task_name,
		p_timesheet task_nr,
		p_timesheet task_type_id,
		p_timesheet task_status_id,
		p_timesheet task_uom_id,
		p_description
	);

	return v_timesheet task_id;
end;' language 'plpgsql';



-- Delete a single timesheet task (if we know its ID...)
create or replace function  im_timesheet task__delete (integer)
returns integer as '
declare
	p_timesheet task_id alias for $1;	-- timesheet task_id
begin
	-- Erase the timesheet task
	delete from 	im_timesheet tasks
	where		timesheet task_id = p_timesheet task_id;

        -- Erase the object
        PERFORM acs_object__delete(p_timesheet task_id);
        return 0;
end;' language 'plpgsql';


create or replace function im_timesheet task__name (integer)
returns varchar as '
declare
	p_timesheet task_id alias for $1;	-- timesheet task_id
	v_name	varchar(40);
begin
	select	timesheet task_nr
	into	v_name
	from	im_timesheet tasks
	where	timesheet task_id = p_timesheet task_id;
	return v_name;
end;' language 'plpgsql';



---------------------------------------------------------
-- Setup the "Materials" main menu entry
--

create or replace function inline_0 ()
returns integer as '
declare
        -- Menu IDs
        v_menu                  integer;
	v_main_menu		integer;
	v_admin_menu		integer;

        -- Groups
        v_employees             integer;
        v_accounting            integer;
        v_senman                integer;
        v_companies             integer;
        v_freelancers           integer;
        v_proman                integer;
        v_admins                integer;
BEGIN

    select group_id into v_admins from groups where group_name = ''P/O Admins'';
    select group_id into v_senman from groups where group_name = ''Senior Managers'';
    select group_id into v_proman from groups where group_name = ''Project Managers'';
    select group_id into v_accounting from groups where group_name = ''Accounting'';
    select group_id into v_employees from groups where group_name = ''Employees'';
    select group_id into v_companies from groups where group_name = ''Customers'';
    select group_id into v_freelancers from groups where group_name = ''Freelancers'';

    select menu_id
    into v_admin_menu
    from im_menus
    where label=''project'';

    v_menu := im_menu__new (
        null,                   -- p_menu_id
        ''acs_object'',         -- object_type
        now(),                  -- creation_date
        null,                   -- creation_user
        null,                   -- creation_ip
        null,                   -- context_id
        ''intranet-task'',	-- package_name
        ''task'',   	-- label
        ''Tasks'',   -- name
        ''/intranet-task/'', -- url
        75,                     -- sort_order
        v_admin_menu,            -- parent_menu_id
        null                    -- p_visible_tcl
    );

    PERFORM acs_permission__grant_permission(v_menu, v_admins, ''read'');
    PERFORM acs_permission__grant_permission(v_menu, v_senman, ''read'');
--    PERFORM acs_permission__grant_permission(v_menu, v_proman, ''read'');
--    PERFORM acs_permission__grant_permission(v_menu, v_accounting, ''read'');
--    PERFORM acs_permission__grant_permission(v_menu, v_employees, ''read'');
--    PERFORM acs_permission__grant_permission(v_menu, v_companies, ''read'');
--    PERFORM acs_permission__grant_permission(v_menu, v_freelancers, ''read'');

    return 0;
end;' language 'plpgsql';

select inline_0 ();
drop function inline_0 ();




-- Timesheet TaskList
--
delete from im_view_columns where column_id >= 90000 and column_id < 90099;

insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (90000,900,NULL,'Nr',
'"<a href=/intranet-timesheet task/new?[export_url_vars timesheet task_id return_url]>$timesheet task_nr</a>"',
'','',0,'');

insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (90002,900,NULL,'Name',
'"<a href=/intranet-timesheet task/new?[export_url_vars timesheet task_id return_url]>$timesheet task_name</a>"',
'','',2,'');

insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (90004,900,NULL,'Type',
'$timesheet task_type','','',4,'');

insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (90006,900,NULL,'Status',
'$timesheet task_status','','',6,'');

insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (90008,900,NULL,'UoM',
'$uom','','',8,'');

insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (90010,900,NULL,
'Description', '$description', '','',10,'');




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

\i intranet-absences-create.sql
\i ../common/intranet-timesheet-common.sql
\i ../common/intranet-timesheet-backup.sql

