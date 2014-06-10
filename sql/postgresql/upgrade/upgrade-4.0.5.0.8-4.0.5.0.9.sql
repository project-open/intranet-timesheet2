-- 
-- 
-- 
-- @author Malte Sussdorff (malte.sussdorff@cognovis.de)
-- @creation-date 2013-01-14
-- @cvs-id $Id$
--

SELECT acs_log__debug('/packages/intranet-timesheet2/sql/postgresql/upgrade/upgrade-4.0.5.0.8-4.0.5.0.9.sql','');


-- ------------------------------------------------------
--------------------------------------------------------------
-- Remaining Vacation View
delete from im_view_columns where view_id = 291;
delete from im_views where view_id = 291;
delete from im_view_columns where view_id = 1013;
delete from im_views where view_id = 1013;


insert into im_views (view_id, view_name, view_label) 
values (291, 'remaining_vacation_list', 'Remaining Vacation');

insert into im_view_columns (column_id, view_id, column_name, column_render_tcl, sort_order, variable_name) 
values (29100,291,'Owner','"<a href=''/intranet-timesheet2/absences/index?user_selection=$employee_id&timescale=all&absence_type_id=$absence_type_id''>$owner_name</a>"',0,'owner_name');

insert into im_view_columns (column_id, view_id, column_name, column_render_tcl, sort_order,variable_name) 
values (29110,291,'Department Name','"$department_name"',10,'department_name');

insert into im_view_columns (column_id, view_id, column_name, column_render_tcl, sort_order,variable_name) 
values (29112,291,'Total Absence Days','$total_absence_days',12,'total_absence_days');

insert into im_view_columns (column_id, view_id, column_name, column_render_tcl, sort_order,variable_name) 
values (29123,291,'Taken Absence Days this year','$taken_absence_days_this_year',23,'taken_absence_days_this_year');

insert into im_view_columns (column_id, view_id, column_name, column_render_tcl, sort_order,variable_name) 
values (29130,291,'Remaining Absences This Year','$remaining_absence_days_this_year',30,'remaining_absence_days_this_year');

insert into im_view_columns (column_id, view_id, column_name, column_render_tcl, sort_order,variable_name) 
values (29132,291,'Requested Absence Days This year','"$requested_absence_days_this_year"',32,'requested_absence_days_this_year');

insert into im_view_columns (column_id, view_id, column_name, column_render_tcl, sort_order,variable_name) 
values (29135,291,'Entitlement Days this year','"$entitlement_days_this_year"',35,'entitlement_days_this_year');

insert into im_view_columns (column_id, view_id, column_name, column_render_tcl, sort_order,variable_name) 
values (29140,291,'Entitlement Days Total','"$entitlement_days_total"',40,'entitlement_days_total');

insert into im_view_columns (column_id, view_id, column_name, column_render_tcl, sort_order,variable_name) 
values (29144,291,'Remaining Vacation Days','"$remaining_vacation_days"',44,'remaining_vacation_days');
