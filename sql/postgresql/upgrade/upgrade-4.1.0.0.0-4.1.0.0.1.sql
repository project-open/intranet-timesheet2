SELECT acs_log__debug('/packages/intranet-timesheet2/sql/postgresql/upgrade/upgrade-4.1.0.0.0-4.1.0.0.1.sql','');

create or replace function inline_1 ()
returns integer as '
declare
        v_menu                  integer;
        v_parent_menu    	integer;
        v_admins                integer;
	v_managers		integer;
	v_hr_managers		integer;
begin

    select group_id into v_admins from groups where group_name = ''P/O Admins'';
    select group_id into v_managers from groups where group_name = ''Senior Managers'';
    select group_id into v_hr_managers from groups where group_name = ''HR Managers'';

    select menu_id into v_parent_menu from im_menus where label=''timesheet2_absences'';

    v_menu := im_menu__new (
        null,                   -- p_menu_id
        ''im_menu'',		-- object_type
        now(),                  -- creation_date
        null,                   -- creation_user
        null,                   -- creation_ip
        null,                   -- context_id
        ''intranet-timesheet2'', -- package_name
        ''new-rwh'',  -- label
        ''Reduction in Working Hours'',  -- name
        ''/intranet-timesheet2/absences/new-rwh'', -- url
        70,                    -- sort_order
        v_parent_menu,           -- parent_menu_id
        ''[im_user_is_hr_p $user_id]''                   -- p_visible_tcl
    );

    PERFORM acs_permission__grant_permission(v_menu, v_admins, ''read'');
    PERFORM acs_permission__grant_permission(v_menu, v_managers, ''read'');
    PERFORM acs_permission__grant_permission(v_menu, v_hr_managers, ''read'');

    return 0;
end;' language 'plpgsql';
select inline_1 ();
drop function inline_1();
