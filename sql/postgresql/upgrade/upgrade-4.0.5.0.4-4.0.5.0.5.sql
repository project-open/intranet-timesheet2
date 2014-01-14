-- upgrade-4.0.5.0.4-4.0.5.0.5.sql

SELECT acs_log__debug('/packages/intranet-timesheet2/sql/postgresql/upgrade/upgrade-4.0.5.0.4-4.0.5.0.5.sql','');


-- Rename add_hours_for_direct_reports into add_hours_direct_reports
--
select acs_privilege__create_privilege('add_hours_direct_reports','Add hours for direct reports','Add hours for direct reports');

update acs_privilege_hierarchy
set child_privilege = 'add_hours_direct_reports'
where child_privilege = 'add_hours_for_direct_reports';
update acs_privilege_hierarchy
set privilege = 'add_hours_direct_reports'
where privilege = 'add_hours_for_direct_reports';

update acs_privilege_hierarchy_index
set child_privilege = 'add_hours_direct_reports'
where child_privilege = 'add_hours_for_direct_reports';
update acs_privilege_hierarchy_index
set privilege = 'add_hours_direct_reports'
where privilege = 'add_hours_for_direct_reports';

update acs_privilege_descendant_map
set descendant = 'add_hours_direct_reports'
where descendant = 'add_hours_for_direct_reports';
update acs_privilege_descendant_map
set privilege = 'add_hours_direct_reports'
where privilege = 'add_hours_for_direct_reports';


update acs_permissions
set privilege = 'add_hours_direct_reports'
where privilege = 'add_hours_for_direct_reports';


select acs_privilege__drop_privilege('add_hours_for_direct_reports');

