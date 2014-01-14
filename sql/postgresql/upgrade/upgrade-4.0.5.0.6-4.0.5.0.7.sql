-- upgrade-4.0.5.0.6-4.0.5.0.7.sql

SELECT acs_log__debug('/packages/intranet-timesheet2/sql/postgresql/upgrade/upgrade-4.0.5.0.6-4.0.5.0.7.sql','');


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





-- Delete old privilege add_hours_for_subordinates
--
delete from acs_permissions where privilege = 'add_hours_for_subordinates';
select acs_privilege__drop_privilege('add_hours_for_subordinates');




-- Add privilege to add absences for direct_reports
select acs_privilege__create_privilege('add_absences_direct_reports','Add absences for direct reports','Add absences for direct reports');
select acs_privilege__add_child('create', 'add_absences_direct_reports');
select im_priv_create('add_absences_direct_reports', 'HR Managers');
select im_priv_create('add_absences_direct_reports', 'Senior Managers');
