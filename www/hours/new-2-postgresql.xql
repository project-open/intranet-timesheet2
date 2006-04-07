<?xml version="1.0"?>
<!DOCTYPE queryset PUBLIC "-//OpenACS//DTD XQL 1.0//EN" "/usr/share/emacs/DTDs/xql.dtd">
<!-- packages/intranet-timesheet2/www/hours/new-2-postgresql.xql -->
<!-- @author  Frank Bergmann (frank.bergmann@project-open.com) -->
<!-- @creation-date 2004-09-09 -->
<!-- @arch-tag 761b5534-d01b-4538-bd3d-4b3df8f10419 -->
<!-- @cvs-id $Id: intranet-biz-object-procs-postgresql.xql,v 1.1 2004/09/09 16:58:19 cvs Exp \
$ -->

<queryset>

  <rdbms>
    <type>postgresql</type>
    <version>7.2</version>
  </rdbms>


  <fullquery name="task_insert">
    <querytext>
    BEGIN
        PERFORM im_timesheet_task__new (
                :task_id,               -- p_task_id
                'im_timesheet_task',    -- object_type
                now(),                  -- creation_date
                null,                   -- creation_user
                null,                   -- creation_ip
                null,                   -- context_id

                :task_nr,
                :task_name,
                :project_id,
                :material_id,
                :cost_center_id,
                :uom_id,
                :task_type_id,
                :task_status_id,
                :description
        );
        return 0;
    END;
    </querytext>
  </fullquery>


  <fullquery name="task_delete">
    <querytext>
    BEGIN
        PERFORM im_task__delete (:task_id);
        return 0;
    END;
    </querytext>
  </fullquery>


  <fullquery name="task_update">
    <querytext>
        update im_timesheet_tasks set
                task_name       = :task_name,
                task_nr         = :task_nr,
                project_id      = :project_id,
                material_id     = :material_id,
                cost_center_id  = :cost_center_id,
                task_type_id    = :task_type_id,
                task_status_id  = :task_status_id,
                uom_id          = :uom_id,
                planned_units   = :planned_units,
                billable_units  = :billable_units,
                description     = :description
        where
                task_id = :task_id;
    </querytext>
  </fullquery>


  <fullquery name="delete_timesheet_costs">
    <querytext>

      DECLARE
         row RECORD;
      BEGIN
         for row in
		select	cost_id
		from	im_costs
		where	cost_type_id = [im_cost_type_timesheet]
			and project_id = :project_id
			and effective_date = to_date(:julian_date, 'J')
			and cause_object_id = :timesheet_task_id
         loop
                PERFORM im_cost__delete(row.cost_id);
         end loop;
         return 0;
      END;

    </querytext>
  </fullquery>


  <fullquery name="update_timesheet_task">
    <querytext>

	update im_timesheet_tasks
	set reported_units_cache = (
		select	sum(h.hours)
		from	im_hours h
		where	h.timesheet_task_id = task_id
	)
	where task_id = :timesheet_task_id

    </querytext>
  </fullquery>


</queryset>




