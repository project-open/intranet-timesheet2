-- 
-- 
-- 
-- @author Malte Sussdorff (malte.sussdorff@cognovis.de)
-- @creation-date 2013-01-14
-- @cvs-id $Id$
--

SELECT acs_log__debug('/packages/intranet-timesheet2/sql/postgresql/upgrade/upgrade-4.0.3.3.3-4.0.3.3.4.sql','');

-- Create a plugin for the Vacation Balance
SELECT im_component_plugin__new (
	null,				-- plugin_id
	'im_component_plugin',		-- object_type
	now(),				-- creation_date
	null,				-- creation_user
	null,				-- creation_ip
	null,				-- context_id
	'Absence List',		-- plugin_name
	'intranet-timesheet2',		-- package_name
	'left',				-- location
	'/intranet/users/view',		-- page_url
	null,				-- view_name
	20,				-- sort_order
	'im_absence_user_component -user_id $user_id'	-- component_tcl
);

-- The component itself does a more thorough check
SELECT acs_permission__grant_permission(
	(select plugin_id from im_component_plugins where plugin_name = 'Vacation Balance' and package_name = 'intranet-timesheet2'), 
	(select group_id from groups where group_name = 'Employees'),
	'read'
);

