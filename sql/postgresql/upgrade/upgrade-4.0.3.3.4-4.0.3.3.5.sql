-- 
-- 
-- 
-- @author Malte Sussdorff (malte.sussdorff@cognovis.de)
-- @creation-date 2013-01-14
-- @cvs-id $Id$
--

SELECT acs_log__debug('/packages/intranet-timesheet2/sql/postgresql/upgrade/upgrade-4.0.3.3.4-4.0.3.3.5.sql','');

-- ------------------------------------------------------
-- Components for timesheet approval
-- ------------------------------------------------------

-- Show the workflow component in project page
--
SELECT im_component_plugin__new (
        null,                           -- plugin_id
        'acs_object',                   -- object_type
        now(),                          -- creation_date
        null,                           -- creation_user
        null,                           -- creation_ip
        null,                           -- context_id
        'Timesheet Approval Component',      -- plugin_name
        'intranet-timesheet2',            -- package_name
        'left',                         -- location
        '/intranet/index',              -- page_url
        null,                           -- view_name
        1,                              -- sort_order
	'im_timesheet_approval_component -user_id $user_id'
);

--------------------------------------------------------------
-- Home Inbox View
delete from im_view_columns where view_id = 270;
delete from im_views where view_id = 270;

insert into im_views (view_id, view_name, visible_for) 
values (270, 'timesheet_approval_inbox', '');

insert into im_view_columns (column_id, view_id, column_name, column_render_tcl, sort_order) 
values (27000,270,'Approve','"<a class=button href=$approve_url>$next_action_l10n</a>"',0);

insert into im_view_columns (column_id, view_id, column_name, column_render_tcl, sort_order) 
values (27010,270,'Hours','"$hours"',10);

insert into im_view_columns (column_id, view_id, column_name, column_render_tcl, sort_order) 
values (27020,270,'Object Name','"<a href=$object_url>$object_name</a>"',20);

insert into im_view_columns (column_id, view_id, column_name, column_render_tcl, sort_order) 
values (27030,270,'Status','"$status"',30);

insert into im_view_columns (column_id, view_id, column_name, column_render_tcl, sort_order) 
values (27090,270,'Deny','"<a class=button href=$deny_url>Deny</a>"',90);

