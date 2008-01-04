-- /packages/intranet-timesheet2/sql/postgres/intranet-absences-workflow.sql
--
-- Copyright (C) 2007 ]project-open[
-- All rights reserved.
--
-- @author      frank.bergmann@project-open.com



-- Enable callback that bypasses the transition if the absences has the specified status.
-- This callback is used with all absences workflows to bypass the very first "complete"
-- step. This step is not necessary if the object has been correctly filled out.
-- The transition is kept as the first transition in the WF only for estetic reasons.
--
create or replace function im_user_absence__fire_on_status (integer,text,text)
returns integer as '
declare
	p_case_id		alias for $1;
	p_transition_key	alias for $2;
	p_custom_arg		alias for $3;

	v_task_id		integer;
	v_case_id		integer;
	v_absence_id		integer;
	v_creation_user		integer;
	v_creation_ip		varchar;
	v_journal_id		integer;
	v_transition_key	varchar;
	v_workflow_key		varchar;

	v_status		varchar;
	v_str			text;
	row			RECORD;
begin
	-- Select out some frequently used variables of the environment
	select	c.object_id, c.workflow_key, task_id
	into	v_absence_id, v_workflow_key, v_task_id
	from	wf_tasks t, wf_cases c
	where	c.case_id = p_case_id
		and t.case_id = c.case_id
		and t.workflow_key = c.workflow_key
		and t.transition_key = p_transition_key;

	RAISE NOTICE ''im_user_absence__fire_on_status: task_id=%, custom_arg=%, absence_id=%'', 
		v_task_id, p_custom_arg, v_absence_id;

	-- Get the status of the absence
	select	im_category_from_id(a.absence_status_id) into v_status
	from	im_user_absences a where absence_id = v_absence_id;

	IF lower(v_status) = lower(p_custom_arg) THEN

		v_journal_id := journal_entry__new(
		    null, v_case_id,
		    v_transition_key || '' approve_rfc unassigned '' || p_custom_arg,
		    v_transition_key || '' approve_rfc unassigned '' || p_custom_arg,
		    now(), v_creation_user, v_creation_ip,
		    ''Bypassing transition with absence status: '' || p_custom_arg
		);
	
		-- Consume tokens from incoming places and put out tokens to outgoing places
		PERFORM workflow_case__fire_transition_internal (v_task_id, v_journal_id);
	END IF;
	return 0;
end;' language 'plpgsql';


-- Enable callback that sets the status of the underlying object
--
create or replace function im_user_absence__set_object_status_id (integer,text,text)
returns integer as '
declare
	p_case_id		alias for $1;
	p_transition_key	alias for $2;
	p_custom_arg		alias for $3;

	v_task_id		integer;
	v_case_id		integer;
	v_absence_id		integer;
	v_creation_user		integer;
	v_creation_ip		varchar;
	v_journal_id		integer;
	v_transition_key	varchar;
	v_workflow_key		varchar;

	v_status		varchar;
	v_str			text;
	row			RECORD;
begin
	-- Select out some frequently used variables of the environment
	select	c.object_id, c.workflow_key, task_id
	into	v_absence_id, v_workflow_key, v_task_id
	from	wf_tasks t, wf_cases c
	where	c.case_id = p_case_id
		and t.case_id = c.case_id
		and t.workflow_key = c.workflow_key
		and t.transition_key = p_transition_key;

	RAISE NOTICE ''im_user_absence__set_object_status_id: task_id=%, custom_arg=%, absence_id=%'', 
		v_task_id, p_custom_arg, v_absence_id;

	update im_user_absences set
	       absence_status_id = p_custom_arg::integer
	where absence_id = v_absence_id;

	return 0;
end;' language 'plpgsql';




-- Unassigned callback that assigns the transition to the supervisor of the absence owner.
--
create or replace function im_user_absence__assign_to_supervisor (integer,text)
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



-- Unassigned callback that assigns the transition to the owner of the underlying object.
--
create or replace function im_user_absence__assign_to_object_owner (integer,text)
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

	RAISE NOTICE ''im_user_absence__assign_to_object_owner: task_id=%, custom_arg=%, absence_id=%, owner_id=%'', 
		p_task_id, p_custom_arg, v_absence_id, v_owner_id;

	IF v_creation_user is not null THEN
		v_journal_id := journal_entry__new(
		    null, v_case_id,
		    v_transition_key || '' assign_to_owner '' || v_owner_name,
		    v_transition_key || '' assign_to_owner '' || v_owner_name,
		    now(), v_creation_user, v_creation_ip,
		    ''Assigning to '' || v_owner_name || ''.''
		);
		PERFORM workflow_case__add_task_assignment(p_task_id, v_creation_user, ''f'');
		PERFORM workflow_case__notify_assignee (p_task_id, v_creation_user, null, null, ''wf_im_user_absence_complete_notif'');
	END IF;
	return 0;
end;' language 'plpgsql';



