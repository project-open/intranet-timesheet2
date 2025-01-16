-- upgrade-5.1.0.0.2-5.1.0.0.3.sql

SELECT acs_log__debug('/packages/intranet-timesheet2/sql/postgresql/upgrade/upgrade-5.1.0.0.2-5.1.0.0.3.sql','');



delete from im_view_columns where column_id = 20002;

insert into im_view_columns (view_id, column_id, sort_order, column_name, column_render_tcl)
values (200, 20002, 2, 'Days','"$duration_days"');



create or replace function inline_0 ()
returns integer as $body$
declare
	v_menu			integer;
	v_admin_menu		integer;
	v_main_menu		integer;
BEGIN
	select menu_id into v_main_menu from im_menus where label = 'timesheet2_absences';
	v_admin_menu := im_menu__new (
		null, 'im_menu', now(), null, null, null,
		'intranet-timesheet2',	-- package_name
		'user_absences_csv',	-- label
		'Export Absences CSV',	-- name
		'/intranet-dw-light/absences.csv?',	-- url
		120,			-- sort_order
		v_main_menu,		-- parent_menu_id
		null			-- P_visible_tcl
	);

	return 0;
end;$body$ language 'plpgsql';
-- Fraber 2025-01-16 disabled in favor of calculating in page
-- select inline_0 ();
drop function inline_0 ();
