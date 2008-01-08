-- /packages/intranet-timesheet2/sql/postgres/intranet-absences-workflow.sql
--
-- Copyright (c) 2008 ]project-open[
-- All rights reserved.
--
-- @author      frank.bergmann@project-open.com



-- Unassigned callback that assigns the transition to the supervisor of the absence owner.
--
create or replace function im_user_absence__assign_to_project_manager (integer,text)
returns integer as '
declare
	p_task_id		alias for $1;
	p_custom_arg		alias for $2;

	v_case_id		integer;
	v_absence_id		integer;
	v_creation_user		integer;
	v_creation_ip		varchar;
	v_journal_id		integer;
	v_transition_key	varchar;
	v_transition_name	varchar;

	v_owner_id		integer;
	v_owner_name		varchar;
	v_supervisor_id		integer;
	v_supervisor_name	varchar;
	v_str			text;
	row			RECORD;
begin
	-- Get information about the transition and the "environment"
	select	t.case_id, tr.transition_name, tr.transition_key, c.object_id, o.creation_user, o.creation_ip
	into	v_case_id, v_transition_name, v_transition_key, v_absence_id, v_creation_user, v_creation_ip
	from	wf_tasks t, wf_cases c, wf_transitions tr, acs_objects o
	where	t.task_id = p_task_id
		and t.case_id = c.case_id
		and o.object_id = t.case_id
		and t.workflow_key = tr.workflow_key
		and t.transition_key = tr.transition_key;

	select	a.owner_id, im_name_from_user_id(a.owner_id), e.supervisor_id, im_name_from_user_id(e.supervisor_id)
	into	v_owner_id, v_owner_name, v_supervisor_id, v_supervisor_name
	from	im_user_absences a, im_employees e
	where	a.absence_id = v_absence_id
		and e.employee_id = a.owner_id;

	RAISE NOTICE ''im_user_absence__assign_to_supervisor: task_id=%, custom_arg=%, absence_id=%, owner_id=%, superv=%'', 
		p_task_id, p_custom_arg, v_absence_id, v_owner_id, v_supervisor_id;

	IF v_supervisor_id is not null THEN
		v_journal_id := journal_entry__new(
		    null, v_case_id,
		    v_transition_key || '' assign_to_supervisor '' || v_supervisor_name,
		    v_transition_key || '' assign_to_supervisor '' || v_supervisor_name,
		    now(), v_creation_user, v_creation_ip,
		    ''Assigning to '' || v_supervisor_name || '', the supervisor of '' || v_owner_name || ''.''
		);
		PERFORM workflow_case__add_task_assignment(p_task_id, v_supervisor_id, ''f'');
		PERFORM workflow_case__notify_assignee (p_task_id, v_supervisor_id, null, null, ''wf_im_user_absence_review_notif'');
	END IF;
	return 0;
end;' language 'plpgsql';

