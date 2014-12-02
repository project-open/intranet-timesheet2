SELECT acs_log__debug('/packages/intranet-timesheet2/sql/postgresql/upgrade/upgrade-4.1.0.0.4-4.1.0.0.5.sql','');

create or replace function inline_1 ()
returns integer as
$$
begin

    perform im_component_plugin__delete(plugin_id) 
    from im_component_plugins 
    where plugin_name in ('Absence Calendar','Calendar View of Absences');


perform im_component_plugin__new (
    null,				    -- plugin_id
    'im_component_plugin',	-- object_type
    now(),				    -- creation_date
    null,				    -- creation_user
    null,				    -- creation_ip
    null,				    -- context_id
    'Absence Calendar',			-- plugin_name
    'intranet-timesheet2',	-- package_name
    'left',				    -- location
    '/intranet/users/view',	-- page_url
    null,				    -- view_name
    20,				        -- sort_order
    E'im_absence_calendar_component \\
                   -absence_status_id $filter_status_id \\
                   -absence_type_id $org_absence_type_id \\
                   -owner_id [im_coalesce $user_id_from_search [ad_get_user_id]] \\
                   -year [clock format [clock seconds] -format "%Y"]'	-- component_tcl
);



-- Create a plugin for the absence calendar for one user
perform im_component_plugin__new (
    null,				    -- plugin_id
    'im_component_plugin',	-- object_type
    now(),				    -- creation_date
    null,				    -- creation_user
    null,				    -- creation_ip
    null,				    -- context_id
    'Calendar View of Absences',			-- plugin_name
    'intranet-timesheet2',	-- package_name
    'top',				    -- location
    '/intranet-timesheet2/absences/index',	-- page_url
    null,				    -- view_name
    20,				        -- sort_order
    E'im_absence_calendar_component \\
                   -absence_status_id $filter_status_id \\
                   -absence_type_id $org_absence_type_id \\
                   -owner_id [im_coalesce $user_id_from_search $user_selection [ad_get_user_id]] \\
                   -year [im_year_from_date $timescale_date]'	-- component_tcl
);

    perform acs_permission__grant_permission(
        plugin_id,
        (select group_id from groups where group_name = 'Employees'),
        'read')
    from im_component_plugins 
    where plugin_name in ('Absence Calendar','Calendar View of Absences')
    and package_name = 'intranet-timesheet2';


return 0;
end;
$$ language 'plpgsql';
select inline_1 ();
drop function inline_1();

