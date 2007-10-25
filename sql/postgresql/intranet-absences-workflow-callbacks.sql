-- ------------------------------------------------
-- /intranet-timesheet2/sql/postgresql/intranet-absences-workflow-callbacks.sql
-- ------------------------------------------------
--
-- Callback functions for Absence Workflow
-- Author: frank.bergmann@project-open.com


-- Debugging: Set the time interval to minutes instead of days
--

-- create or replace function wf_callback__time_sysdate_plus_x (integer,varchar,text)
-- returns timestamptz as '
-- declare
--   time_sysdate_plus_x__case_id          alias for $1;
--   time_sysdate_plus_x__transition_key   alias for $2;
--   time_sysdate_plus_x__custom_arg       alias for $3;
-- begin
--         return now() + (time_sysdate_plus_x__custom_arg || '' days'')::interval;
-- end;' language 'plpgsql';



-- ------------------------------------------------
-- Set the absence status to the given parameter


CREATE or REPLACE FUNCTION im_user_absence_wf__set_absence_status_id  (integer,text,text)
RETURNS integer as '
DECLARE
	p_case_id           alias for $1;
	p_transition_key    alias for $2;
	p_custom_arg        alias for $3;

	v_absence_id		integer;
	row			RECORD;
BEGIN
	-- Get information about our environment
	SELECT	c.object_id INTO v_absence_id
	FROM	wf_cases c
	WHERE	c.case_id = p_case_id;

	RAISE NOTICE 
		''set_absence_status_id: case_id=%, transition_key=%, status_id=%, absence_id=%'', 
		p_case_id, p_transition_key, p_custom_arg, v_absence_id;

	UPDATE	im_user_absences
	SET	absence_status_id = p_custom_arg::integer
	WHERE	absence_id = v_absence_id;
	
	RETURN 0;
END;' language 'plpgsql';
