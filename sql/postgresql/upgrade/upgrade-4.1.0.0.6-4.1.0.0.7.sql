SELECT acs_log__debug('/packages/intranet-timesheet2/sql/postgresql/upgrade/upgrade-4.1.0.0.6-4.1.0.0.7.sql','');

-- -------------------------------------------------------
-- Create new Absence types for weekends
-- -------------------------------------------------------

CREATE OR REPLACE FUNCTION inline_0 () 
RETURNS INTEGER AS
$$
declare
begin

    perform im_component_plugin__delete(plugin_id) 
    from im_component_plugins 
    where plugin_name in ('Project Approval Component');


    -- Create a plugin for the absence cube
    perform im_component_plugin__new (
        null,                               -- plugin_id
        'im_component_plugin',              -- object_type
        now(),                              -- creation_date
        null,                               -- creation_user
        null,                               -- creation_ip
        null,                               -- context_id
        'Project Approval Component',       -- plugin_name
        'intranet-timesheet2',              -- package_name
        'right',                            -- location
        '/intranet/projects/view',          -- page_url
        null,                               -- view_name
        20,                                 -- sort_order
        'im_timesheet_approval_component -project_id $project_id' -- component_tcl
    );

    perform acs_permission__grant_permission(
        plugin_id,
        (select group_id from groups where group_name = 'Project Managers'),
        'read')
    from im_component_plugins 
    where plugin_name in ('Project Approval Component')
    and package_name = 'intranet-timesheet2';


    return 1;

end;
$$ LANGUAGE 'plpgsql';

SELECT inline_0 ();
DROP FUNCTION inline_0 ();

