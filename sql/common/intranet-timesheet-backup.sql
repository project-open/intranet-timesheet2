-- /packages/intranet-timesheet2/sql/oracle/intranet-timesheet-backup.sql
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
-- Backup & Restore
--

-- 100  im_projects
-- 101  im_project_roles
-- 102  im_customers
-- 103  im_customer_roles
-- 104  im_offices
-- 105  im_office_roles
-- 106  im_categories
-- 107	im_employees
--
-- 110  users
-- 111  im_profiles
--
-- 120  im_freelancers
-- 121  im_freelance_skills
--
-- 130  im_forum_topics
-- 131	im_forum_folders
-- 132	im_forum_topic_user_map
--
-- 140  im_filestorage
--
-- 150  im_translation
-- 151	im_target_languages
-- 152	im_project_trans_details
--
-- 160  im_quality
--
-- 170  im_marketplace
--
-- 180  im_hours
-- 181  im_absences
--
-- 190  im_costs
-- 191  im_payments
-- 192  im_invoices
-- 193  im_invoice_items
-- 194  im_project_invoice_map
-- 195  im_trans_prices
-- 196	im_cost_centers
-- 197	im_investments



---------------------------------------------------------
-- Backup Hours
--

delete from im_view_columns where view_id = 180;
delete from im_views where view_id = 180;
insert into im_views (
	view_id, view_name, view_type_id, sort_order, view_sql
) values (180, 'im_hours', 1410, 130, '
select
	h.*,
	im_email_from_user_id(h.user_id) as user_email,
	p.project_name
from
	im_hours h,
	im_projects p
where
	h.project_id = p.project_id
');

delete from im_view_columns where column_id > 18004 and column_id < 18099;
--
insert into im_view_columns (column_id, view_id, group_id, column_name, 
column_render_tcl, extra_select, extra_where, sort_order, visible_for) values (
18001,180,NULL,'user_email','$user_email','','',1,'');
insert into im_view_columns (column_id, view_id, group_id, column_name, 
column_render_tcl, extra_select, extra_where, sort_order, visible_for) values (
18003,180,NULL,'project_name','$project_name','','',3,'');
insert into im_view_columns (column_id, view_id, group_id, column_name, 
column_render_tcl, extra_select, extra_where, sort_order, visible_for) values (
18005,180,NULL,'day','$day','','',5,'');
insert into im_view_columns (column_id, view_id, group_id, column_name, 
column_render_tcl, extra_select, extra_where, sort_order, visible_for) values (
18007,180,NULL,'hours','$hours','','',7,'');
insert into im_view_columns (column_id, view_id, group_id, column_name, 
column_render_tcl, extra_select, extra_where, sort_order, visible_for) values (
18009,180,NULL,'billing_rate','$billing_rate','','',9,'');
insert into im_view_columns (column_id, view_id, group_id, column_name, 
column_render_tcl, extra_select, extra_where, sort_order, visible_for) values (
18011,180,NULL,'billing_currency','$billing_currency','','',11,'');
insert into im_view_columns (column_id, view_id, group_id, column_name, 
column_render_tcl, extra_select, extra_where, sort_order, visible_for) values (
18013,180,NULL,'note','[ns_urlencode $note]','','',11,'');

--
-- commit;



---------------------------------------------------------
-- Backup User Absences
--

delete from im_view_columns where view_id = 181;
delete from im_views where view_id = 181;
insert into im_views (
	view_id, view_name, view_type_id, sort_order, view_sql
) values (
	181, 'im_user_absences', 1410, 140, '
select
	a.*,
	im_email_from_user_id(a.owner_id) as owner_email,
	im_category_from_id(a.absence_type_id) as absence_type_cat
from
	im_user_absences a
');

delete from im_view_columns where column_id > 18100 and column_id < 18199;
--
insert into im_view_columns (column_id, view_id, group_id, column_name, 
column_render_tcl, extra_select, extra_where, sort_order, visible_for) values (
18101,181,NULL,'owner_email','$owner_email','','',1,'');

insert into im_view_columns (column_id, view_id, group_id, column_name, 
column_render_tcl, extra_select, extra_where, sort_order, visible_for) values (
18103,181,NULL,'start_date','$start_date','','',3,'');

insert into im_view_columns (column_id, view_id, group_id, column_name, 
column_render_tcl, extra_select, extra_where, sort_order, visible_for) values (
18105,181,NULL,'end_date','$end_date','','',5,'');

insert into im_view_columns (column_id, view_id, group_id, column_name, 
column_render_tcl, extra_select, extra_where, sort_order, visible_for) values (
18109,181,NULL,'receive_email_p','$receive_email_p','','',9,'');

insert into im_view_columns (column_id, view_id, group_id, column_name, 
column_render_tcl, extra_select, extra_where, sort_order, visible_for) values (
18111,181,NULL,'absence_type','$absence_type_cat','','',11,'');

insert into im_view_columns (column_id, view_id, group_id, column_name, 
column_render_tcl, extra_select, extra_where, sort_order, visible_for) values (
18107,181,NULL,'contact_info','[ns_urlencode $contact_info]','','',7,'');

insert into im_view_columns (column_id, view_id, group_id, column_name, 
column_render_tcl, extra_select, extra_where, sort_order, visible_for) values (
18113,181,NULL,'description','[ns_urlencode $description]','','',11,'');


--
-- commit;



