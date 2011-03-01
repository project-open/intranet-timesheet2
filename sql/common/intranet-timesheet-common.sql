-- /packages/intranet-timesheet2/sql/common/intranet-timesheet-create.sql
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
create or replace view im_absence_types as
select category_id as absence_type_id, category as absence_type
from im_categories
where category_type = 'Intranet Absence Type';



-- Insert additional columns into the "project_status"
-- view of the project list
delete from im_view_columns where column_id = 2207 or column_id = 2209;
insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (2207,22,NULL,'Spend Days',
'$spend_days','','',4,'im_permission $user_id view_projects');
insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (2209,22,NULL,'Estim. Days',
'$est_days','','',5,'im_permission $user_id view_projects');




--------------------------------------------------------------
-- Create User Absences View
-- vws to "absences" items: 50-59

-- view_columns to "absences" items: 20000-20099
delete from im_view_columns where view_id = 200;
delete from im_views where view_id = 200;
insert into im_views (view_id, view_name, visible_for) 
values (200, 'absence_list_home', 'view_absences_all');


insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (20001,200,NULL,'Name',
'"<a href=$absence_view_url>$absence_name</a>"','','',1,'');
insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (20003,200,NULL,'Date',
'"$start_date - $end_date"','','',3,'');
insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (20005,200,NULL,'User',
'"$user_link"','','',5,'');
insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (20007,200,NULL,'Type',
'"$absence_type"','','',7,'');
insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (20009,200,NULL,'Description',
'"$description"','','',9,'');
insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (20011,200,NULL,'Contact',
'"$contact_info"','','',11,'');


--------------------------------------------------------------
-- Add view column to users and employees overview
-- 
-- 
delete from im_view_columns where column_id = 207;
insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (207, 10, NULL, 'Next Absence',
'"[im_get_next_absence_link $user_id ]"',
'','',10,'');


delete from im_view_columns where column_id = 5507;
insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (5507, 55, NULL, 'Next Absence',
'"[im_get_next_absence_link $user_id ]"',
'','',10,'');







