-- /package/intranet-timesheet2/sql/intranet-timesheet-drop.sql
--
-- Copyright (c) 2003 - 2009 ]project-open[
--
-- All rights reserved. Please check
-- http://www.project-open.com/license/ for details.
--
-- @author frank.bergmann@project-open.com

-----------------------------------------------------
-- Drop menus and components defined by the module

-- BEGIN
    select im_menu__del_module('intranet-timesheet');
    select im_component_plugin__del_module('intranet-timesheet');
-- END;

-- show errors

delete from im_view_columns where column_id = 2207 or column_id = 2209;
delete from im_view_columns where view_id >= 200 and view_id < 209;
delete from im_views where view_id >= 200 and view_id < 209;
delete from im_view_columns where column_id >= 20000 and column_id < 20099;
delete from im_view_columns where column_id = 207;

delete from im_categories where category_id >= 5000 and category_id < 5100;

-- before remove priviliges remove granted permissions
create or replace function inline_revoke_permission (varchar)
returns integer as '
DECLARE
        p_priv_name     alias for $1;
BEGIN
     lock table acs_permissions_lock;

     delete from acs_permissions
     where privilege = p_priv_name;

     return 0;

end;' language 'plpgsql';

-- begin
    select inline_revoke_permission ('add_absences');
    select acs_privilege__remove_child('admin', 'add_absences');
    select acs_privilege__drop_privilege('add_absences');
    select inline_revoke_permission ('view_absences_all');
    select acs_privilege__remove_child('admin', 'view_absences_all');
    select acs_privilege__drop_privilege('view_absences_all');
    select inline_revoke_permission ('add_hours');
    select acs_privilege__remove_child('admin', 'add_hours');
    select acs_privilege__drop_privilege('add_hours');
    select inline_revoke_permission ('view_hours_all');
    select acs_privilege__remove_child('admin', 'view_hours_all');
    select acs_privilege__drop_privilege('view_hours_all');
-- end;

-- commit;


-- commit;

drop function on_vacation_p(timestamptz);
drop view im_absence_types;
drop table im_hours;
-- drop sequence user_vacations_vacation_id_seq;
drop sequence im_user_absences_id_seq;
drop table im_user_absences;
