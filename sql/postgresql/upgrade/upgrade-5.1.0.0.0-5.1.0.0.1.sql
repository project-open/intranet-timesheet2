-- upgrade-5.1.0.0.0-5.1.0.0.1.sql

SELECT acs_log__debug('/packages/intranet-timesheet2/sql/postgresql/upgrade/upgrade-5.1.0.0.0-5.1.0.0.1.sql','');


-- Add privilege to view/add hours for direct_reports
select acs_privilege__create_privilege('add_hours_direct_reports','Add hours for direct reports','Add hours for direct reports');
select acs_privilege__add_child('admin', 'add_hours_direct_reports');
select acs_privilege__create_privilege('view_hours_direct_reports','View hours for direct reports','View hours for direct reports');
select acs_privilege__add_child('admin', 'view_hours_direct_reports');

