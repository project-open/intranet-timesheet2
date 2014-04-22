-- 
-- 
-- 
-- @author Malte Sussdorff (malte.sussdorff@cognovis.de)
-- @creation-date 2013-01-14
-- @cvs-id $Id$
--

SELECT acs_log__debug('/packages/intranet-timesheet2/sql/postgresql/upgrade/upgrade-4.0.5.0.5-4.0.5.0.6.sql','');

-- ------------------------------------------------------
-- Components for absence info
-- ------------------------------------------------------

SELECT im_component_plugin__new (
        null,                           -- plugin_id
        'acs_object',                   -- object_type
        now(),                          -- creation_date
        null,                           -- creation_user
        null,                           -- creation_ip
        null,                           -- context_id
        'Absence Info Component',      -- plugin_name
        'intranet-timesheet2',            -- package_name
        'left',                         -- location
        '/intranet-timesheet2/absences/view',              -- page_url
        null,                           -- view_name
        1,                              -- sort_order
        'im_absence_info_component -absence_id $absence_id'
);

SELECT acs_permission__grant_permission(
        (select plugin_id from im_component_plugins where plugin_name = 'Absence Info Component' and package_name = 'intranet-timesheet2'),
        (select group_id from groups where group_name = 'Employees'),
        'read'
);

SELECT im_component_plugin__new (
        null,                           -- plugin_id
        'acs_object',                   -- object_type
        now(),                          -- creation_date
        null,                           -- creation_user
        null,                           -- creation_ip
        null,                           -- context_id
        'Absence Balance Component',      -- plugin_name
        'intranet-timesheet2',            -- package_name
        'right',                         -- location
        '/intranet-timesheet2/absences/view',              -- page_url
        null,                           -- view_name
        1,                              -- sort_order
        'im_absence_balance_component -user_id $owner_id'
);

SELECT acs_permission__grant_permission(
        (select plugin_id from im_component_plugins where plugin_name = 'Absence Balance Component' and package_name = 'intranet-timesheet2'),
        (select group_id from groups where group_name = 'Employees'),
        'read'
);

update im_component_plugins set page_url = '/intranet-timesheet2/absences/view' where page_url = '/intranet-timesheet2/absences/new';

SELECT im_component_plugin__new (
        null,                           -- plugin_id
        'acs_object',                   -- object_type
        now(),                          -- creation_date
        null,                           -- creation_user
        null,                           -- creation_ip
        null,                           -- context_id
        'Absence Balance Component Edit',      -- plugin_name
        'intranet-timesheet2',            -- package_name
        'right',                         -- location
        '/intranet-timesheet2/absences/new',              -- page_url
        null,                           -- view_name
        1,                              -- sort_order
        'im_absence_balance_component -user_id $owner_id'
);

SELECT acs_permission__grant_permission(
        (select plugin_id from im_component_plugins where plugin_name = 'Absence Balance Component Edit' and package_name = 'intranet-timesheet2'),
        (select group_id from groups where group_name = 'Employees'),
        'read'
);
--------------------------------------------------------------
-- Home Inbox View
delete from im_view_columns where view_id = 281;
delete from im_views where view_id = 281;

insert into im_views (view_id, view_name, visible_for) 
values (281, 'absence_info', '');

insert into im_view_columns (column_id, view_id, column_name, column_render_tcl, sort_order) 
values (28100,281,'Name','$owner_pretty',0);

insert into im_view_columns (column_id, view_id, column_name, column_render_tcl, sort_order) 
values (28110,281,'Start Date','"[lc_time_fmt $start_date "%q"]"',10);

insert into im_view_columns (column_id, view_id, column_name, column_render_tcl, sort_order) 
values (28112,281,'End Date','"[lc_time_fmt $end_date "%q"]"',12);

insert into im_view_columns (column_id, view_id, column_name, column_render_tcl, sort_order) 
values (28123,281,'Duration','$duration_days',23);

insert into im_view_columns (column_id, view_id, column_name, column_render_tcl, sort_order) 
values (28130,281,'Status','"[im_category_from_id $absence_status_id]"',30);

insert into im_view_columns (column_id, view_id, column_name, column_render_tcl, sort_order) 
values (28132,281,'Description','"$description"',32);

insert into im_view_columns (column_id, view_id, column_name, column_render_tcl, sort_order) 
values (28135,281,'Contact Info','"$contact_info"',35);

insert into im_view_columns (column_id, view_id, column_name, column_render_tcl, sort_order) 
values (28140,281,'Vacation Replacement','"$vacation_replacement"',40);
