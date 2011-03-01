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
			and cause_object_id = :user_id_from_search
			and effective_date = to_date(:julian_date, 'J')
         loop
                PERFORM im_cost__delete(row.cost_id);
         end loop;
         return 0;
      END;

    </querytext>
  </fullquery>


  <fullquery name="update_timesheet_task">
    <querytext>

	update im_projects
	set reported_hours_cache = (
		select	sum(h.hours)
		from	im_hours h
		where	h.project_id = :project_id
	)
	where project_id = :project_id

    </querytext>
  </fullquery>


</queryset>




