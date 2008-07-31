# /packages/intranet-timesheet2/www/hours/new.tcl
#
# Copyright (C) 1998-2004 various parties
# The code is based on ArsDigita ACS 3.4
#
# This program is free software. You can redistribute it
# and/or modify it under the terms of the GNU General
# Public License as published by the Free Software Foundation;
# either version 2 of the License, or (at your option)
# any later version. This program is distributed in the
# hope that it will be useful, but WITHOUT ANY WARRANTY;
# without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.
# See the GNU General Public License for more details.

ad_page_contract {
    Displays form to let user enter hours

    @param project_id
    @param julian_date 
    @param return_url 

    @author mbryzek@arsdigita.com
    @author frank.bergmann@project-open.com
    @creation-date Jan 2006
} {
    { project_id:integer 0 }
    { project_id_list:multiple "" }
    { julian_date "" }
    { return_url "" }
    { show_week_p 1 }
    { user_id_from_search "" }
}

# ---------------------------------------------------------
# Default & Security
# ---------------------------------------------------------

set debug 0

set user_id [ad_maybe_redirect_for_registration]
if {"" == $user_id_from_search || ![im_permission $user_id "add_hours_all"]} { set user_id_from_search $user_id }
set user_name_from_search [db_string uname "select im_name_from_user_id(:user_id_from_search)"]

if {"" == $return_url} { set return_url [im_url_with_query] }
set bgcolor(0) " class=roweven "
set bgcolor(1) " class=rowodd "

if {"" == $show_week_p} { set show_week_p 0 }

if { [empty_string_p $julian_date] } {
    set julian_date [db_string sysdate_as_julian "select to_char(sysdate,'J') from dual"]
}

# ---------------------------------------------------------
# Calculate the start and end of the week.
# ---------------------------------------------------------

set julian_week_start $julian_date
set julian_week_end $julian_date
set h_day_in_dayweek "h.day::date = to_date(:julian_date, 'J')"
if {$show_week_p} {

    # Find Sunday (=American week start) and Saturday (=American week end)
    # for the current week by adding or subtracting days depending on the weekday (to_char(.., 'D'))
    set day_of_week [db_string dow "select to_char(to_date(:julian_date, 'J'), 'D')"]
    set julian_week_start [expr $julian_date + 1 - $day_of_week]
    set julian_week_end [expr $julian_date + (7-$day_of_week)]

    # Reset the day to the start of the week.
    set julian_date $julian_week_start

    # Condition to check for hours this week:
    set h_day_in_dayweek "h.day between to_date(:julian_week_start, 'J') and to_date(:julian_week_end, 'J')"
}

# Materials
set materials_p [parameter::get_from_package_key -package_key intranet-timesheet2 -parameter HourLoggingWithMaterialsP -default 0]
set material_options [im_material_options -include_empty 1]
set default_material_id [im_material_default_material_id]


# Project_ID and list of project IDs
if {"" == $project_id} { set project_id 0 }
set project_id_for_default $project_id
if {0 == $project_id} { set project_id_for_default ""}
if {0 == $project_id_list} { set project_id_list {} }
# ad_return_complaint 1 "project_id='$project_id', project_id_list='$project_id_list'"


# "Log hours for a different day"
set different_date_url [export_vars -base "index" {project_id user_id_from_search project_id_list julian_date show_week_p}]


# Append user-defined menus
set bind_vars [ad_tcl_vars_to_ns_set user_id user_id_from_search julian_date return_url show_week_p]
set menu_links_html [im_menu_ul_list -no_uls 1 "timesheet_hours_new_admin" $bind_vars]

set different_project_url "other-projects?[export_url_vars julian_date user_id_from_search]"

# Log Absences
set absences_url [export_vars -base "/intranet-timesheet2/absences/new" {return_url user_id_from_search}]
set absences_link_text [lang::message::lookup "" intranet-timesheet2.Log_Absences "Log Absences"]


db_1row user_name_and_date "
select 
	im_name_from_user_id(user_id) as user_name,
	to_char(to_date(:julian_date, 'J'), 'fmDay fmMonth fmDD, YYYY') as pretty_date
from	users
where	user_id = :user_id_from_search" 


# ---------------------------------------------------------
# Calculate the <- -> buttons at the top of the timesheet page.
# ---------------------------------------------------------

set left_gif [im_gif arrow_comp_left]
set right_gif [im_gif arrow_comp_right]

if {$show_week_p} {

    set page_title [lang::message::lookup "" intranet-timesheet2.The_week_for_user "The week for %user_name_from_search%"]

    set prev_week_julian_date [expr $julian_date - 7]
    set prev_week_url [export_vars -base "new" {{julian_date $prev_week_julian_date} project_id project_id_list show_week_p}]
    set prev_week_link "<a href=$prev_week_url>$left_gif</a>"

    set next_week_julian_date [expr $julian_date + 7]
    set next_week_url [export_vars -base "new" {{julian_date $next_week_julian_date} project_id project_id_list show_week_p}]
    set next_week_link "<a href=$next_week_url>$right_gif</a>"

    set forward_backward_buttons "
	<tr>
	<td align=left>$prev_week_link</td>
	<td colspan=6>&nbsp;</td>
	<td align=right>$next_week_link</td>
	</tr>
    "

} else {

    set page_title "[lang::message::lookup "" intranet-timesheet2.Date_for_user "%pretty_date% for %user_name_from_search%"]"

    set prev_day_julian_date [expr $julian_date - 1]
    set prev_day_url [export_vars -base "new" {{julian_date $prev_day_julian_date} project_id project_id_list show_week_p}]
    set prev_day_link "<a href=$prev_day_url>$left_gif</a>"

    set next_day_julian_date [expr $julian_date + 1]
    set next_day_url [export_vars -base "new" {{julian_date $next_day_julian_date} project_id project_id_list show_week_p}]
    set next_day_link "<a href=$next_day_url>$right_gif</a>"

    set forward_backward_buttons "
	<tr>
	<td align=left>$prev_day_link</td>
	<td colspan=1>&nbsp;</td>
	<td align=right>$next_day_link</td>
	</tr>
    "

}

set context_bar [im_context_bar [list index "[_ intranet-timesheet2.Hours]"] "[_ intranet-timesheet2.Add_hours]"]

set permissive_logging [parameter::get_from_package_key -package_key intranet-timesheet2 -parameter PermissiveHourLogging -default "permissive"]

set log_hours_on_potential_project_p [parameter::get_from_package_key -package_key intranet-timesheet2 -parameter TimesheetLogHoursOnPotentialProjectsP -default 1]

set list_sort_order [parameter::get_from_package_key -package_key "intranet-timesheet2" -parameter TimesheetAddHoursSortOrder -default "order"]

set show_project_nr_p [parameter::get_from_package_key -package_key "intranet-core" -parameter ShowProjectNrAndProjectNameP -default 0]

# Should we allow users to log hours on a parent project, even though it has children?
set log_hours_on_parent_with_children_p [parameter::get_from_package_key -package_key "intranet-timesheet2" -parameter LogHoursOnParentWithChildrenP -default 1]

# Determine how to show the tasks of projects. There are several options:
#	- main_project: The main project determines the subproject/task visibility space
#	- sub_project: Each (sub-) project determines the visibility of its tasks
#	- task: Each task has its own space - the user needs to be member of all tasks to log hours.
set task_visibility_scope [parameter::get_from_package_key -package_key "intranet-timesheet2" -parameter TimesheetTaskVisibilityScope -default "sub_project"]

# Can the current user log hours for other users?
set add_hours_all_p [im_permission $user_id "add_hours_all"]

# What is a closed status?
set closed_stati_select "select * from im_sub_categories([im_project_status_closed])"
if {!$log_hours_on_potential_project_p} {
    append closed_stati_select " UNION select * from im_sub_categories([im_project_status_potential])"
}

# Determine all the members of the "closed" super-status
set closed_stati [db_list closed_stati $closed_stati_select]
set closed_stati_list [join $closed_stati ","]

# ---------------------------------------------------------
# Logic to check if the user is allowed to log hours
# ---------------------------------------------------------

set edit_hours_p "t"

# When should we consider the last month to be closed?
set last_month_closing_day [parameter::get_from_package_key -package_key intranet-timesheet2 -parameter TimesheetLastMonthClosingDay -default 0]
set weekly_logging_days [parameter::get_from_package_key -package_key intranet-timesheet2 -parameter TimesheetWeeklyLoggingDays -default "0 1 2 3 4 5 6"]

if {0 != $last_month_closing_day && "" != $last_month_closing_day} {

    # Check that $julian_date is before the Nth of the next month:
    # Select the 1st day of the last month:
    set first_of_last_month [db_string last_month "
	select to_char(now()::date - :last_month_closing_day::integer + '0 Month'::interval, 'YYYY-MM-01')
    "]
    set edit_hours_p [db_string e "select to_date(:julian_date, 'J') >= :first_of_last_month::date"]

}

set edit_hours_closed_message [lang::message::lookup "" intranet-timesheet2.Logging_hours_has_been_closed "Logging hours for this date has already been closed. <br>Please contact your supervisor or the HR department."]


# ---------------------------------------------------------
# Check for registered hours
# ---------------------------------------------------------

# These are the hours and notes captured from the intranet-timesheet2-task-popup
# modules, if it's there. The module allows the user to capture notes during the
# day on what task she is working.

array set popup_hours [list]
array set popup_notes [list]

set timesheet_popup_installed_p [db_table_exists im_timesheet_popups]
if {$timesheet_popup_installed_p} {

    set timesheet_popup_sql "
	select
	        p.log_time,
	        round(to_char(min(q.log_time) - p.log_time, 'HH24')::integer
	          + to_char(min(q.log_time) - p.log_time, 'MI')::integer / 60.0
	          + to_char(min(q.log_time) - p.log_time, 'SS')::integer / 3600.0
		  , 3)  as log_hours,
	        p.task_id,
	        p.note
	from
	        im_timesheet_popups p,
	        im_timesheet_popups q
	where
		1=1
		and p.log_time::date = now()::date
	        and q.log_time::date = now()::date
	        and q.log_time > p.log_time
		and p.user_id = :user_id_from_search
		and q.user_id = :user_id_from_search
	group by
	        p.log_time,
	        p.task_id,
	        p.note
	order by
	        p.log_time
    "

    db_foreach timesheet_popup $timesheet_popup_sql {
	set p_hours ""
	if {[info exists popup_hours($task_id)]} { set p_hours $popup_hours($task_id) } 
	set p_notes ""
	if {[info exists popup_notes($task_id)]} { set p_notes $popup_notes($task_id) } 

	append p_hours "[expr $log_hours+0]<br>"
	if {"" != [string trim $note] && ![string equal "Timesheet" [string tolower $note]]} {
	    append p_notes "$note<br>"
	}

	set popup_hours($task_id) $p_hours
	set popup_notes($task_id) $p_notes
    }
}


# ---------------------------------------------------------
# Build the SQL Subquery, determining the (parent)
# projects to be displayed 
# ---------------------------------------------------------

# Remove funny "{" or "}" characters in list
regsub -all {[\{\}]} $project_id_list "" project_id_list

set main_project_id_list [list 0]
set main_project_id 0

if {0 != $project_id} {

    set main_project_id [db_string main_p "
	select	main_p.project_id
	from	im_projects p,
		im_projects main_p
	where	p.project_id = :project_id and
		tree_ancestor_key(p.tree_sortkey, 1) = main_p.tree_sortkey
    " -default 0]

    set parent_project_sql "
			select	:main_project_id::integer
    \t\t"

    # Project specified => only one project
    set one_project_only_p 1

    # Make sure the user can see everything below the single main project
    set task_visibility_scope "specified"
    lappend project_id_list 0

} elseif {"" != $project_id_list} {

    set main_project_id_list [db_list main_ps "
	select distinct
		main_p.project_id
	from	im_projects p,
		im_projects main_p
	where	p.project_id in ([join $project_id_list ","]) and
		tree_ancestor_key(p.tree_sortkey, 1) = main_p.tree_sortkey
    "]

    set parent_project_sql "
			select	p.project_id
			from	im_projects p
			where	p.project_id in ([join $main_project_id_list ","])
    \t\t"

    # An entire list of project has been selected
    set one_project_only_p 0

    # Make sure the user can see everything below the single main project
    set task_visibility_scope "specified"

} else {

    # Project_id unknown => select all projects
    set one_project_only_p 0

    set parent_project_sql "
	select	p.project_id
	from	im_projects p
	where 
		p.parent_id is null
		and p.project_id in (
				select	r.object_id_one
				from	acs_rels r
				where	r.object_id_two = :user_id_from_search
			    UNION
				select	project_id
				from	im_hours h
				where	h.user_id = :user_id_from_search
					and $h_day_in_dayweek
		)
		and p.project_status_id not in ($closed_stati_list)
    "
}


# We need to show the hours of already logged projects.
# So we need to add the parents of these sub-projects to parent_project_sql.

append parent_project_sql "
    UNION
	-- Always show the main-projects of projects with logged hours
	select	main_p.project_id
	from	im_hours h,
		im_projects p,
		im_projects main_p
	where	h.user_id = :user_id_from_search
		and $h_day_in_dayweek
		and h.project_id = p.project_id
		and p.tree_sortkey between
			main_p.tree_sortkey and
			tree_right(main_p.tree_sortkey)
"


# Determine how to show the tasks of projects.
switch $task_visibility_scope {
    "main_project" {
	# main_project: The main project determines the subproject/task visibility space
	set children_sql "
				select	sub.project_id
				from	acs_rels r,
					im_projects main,
					im_projects sub
				where	r.object_id_two = :user_id_from_search
					and r.object_id_one = main.project_id
					and main.tree_sortkey = tree_ancestor_key(sub.tree_sortkey, 1)
					and main.project_status_id not in ($closed_stati_list)
					and sub.project_status_id not in ($closed_stati_list)
	"
    }
    "specified" {
	# specified: We've got an explicit "project_id" or "project_id_list".
	# Show everything that's below, even if the user isn't a member.
	set children_sql "
				select	sub.project_id
				from	im_projects main,
					im_projects sub
				where	(	main.project_id = :main_project_id 
						OR main.project_id in ([join $main_project_id_list ","])
					)
					and main.project_status_id not in ($closed_stati_list)
					and sub.project_status_id not in ($closed_stati_list)
					and sub.tree_sortkey between
						main.tree_sortkey and
						tree_right(main.tree_sortkey)
	"
    }
    "sub_project" {
	# sub_project: Each (sub-) project determines the visibility of its tasks.
	# So we are looking for the "lowest" in the project hierarchy subproject
	# that's just above its tasks and controls the visibility of the tasks.
	# There are four conditions to determine the list of the "controlling" projects efficiently:
	#	- the controlling_project is a project
	#	- the task directly below the ctrl_project is a task.
	#	- the current user is member of the controlling project
	#	- the controlling_project is below the visible main projects 
	#	  (optional, may speedup query, but does not in general when all projects are selected)
	#
	# This query is slightly too permissive, because a single task associated with a main project
	# would make the main project the "controlling" project and show _all_ tasks in all subprojects,
	# even if the user doesn't have permissions for those. However, this can be fixed on the TCL level.
	set ctrl_projects_sql "
		select	distinct ctrl.project_id
		from	im_projects ctrl,
			im_projects task,
			acs_rels r
		where	
			task.parent_id = ctrl.project_id
			and ctrl.project_type_id != 100
			and task.project_type_id = 100
			and ctrl.project_status_id not in ($closed_stati_list)
			and task.project_status_id not in ($closed_stati_list)
			and r.object_id_one = ctrl.project_id
			and r.object_id_two = :user_id_from_search
	"

	set children_sql "
				-- Select any subprojects of control projects
				select	sub.project_id
				from	im_projects main,
					($ctrl_projects_sql) ctrl,
					im_projects sub
				where	ctrl.project_id = main.project_id
					and main.project_status_id not in ($closed_stati_list)
					and sub.project_status_id not in ($closed_stati_list)
					and sub.tree_sortkey between
						main.tree_sortkey and
						tree_right(main.tree_sortkey)
			UNION
				-- Select any project or task with explicit membership
				select  r.object_id_one
				from    acs_rels r
				where   r.object_id_two = :user_id_from_search
	"

    }
    "task" {
	# task: Each task has its own space - the user needs to be member of all tasks to log hours.
	set children_sql "
				-- Show sub-project/tasks only with direct membership
				select	r.object_id_one
				from	acs_rels r
				where	r.object_id_two = :user_id_from_search
	"
    }
}


set child_project_sql "
				$children_sql
			    UNION
				-- Always show projects and tasks where user has logged hours
				select	project_id
				from	im_hours h
				where	h.user_id = :user_id_from_search
					and $h_day_in_dayweek
			    UNION
			        -- Project with hours on it plus any of its superiors
				select	main_p.project_id
				from	im_hours h,
					im_projects p,
					im_projects main_p
				where	h.user_id = :user_id_from_search
					and $h_day_in_dayweek
					and h.project_id = p.project_id
					and p.tree_sortkey between
						main_p.tree_sortkey and
						tree_right(main_p.tree_sortkey)				
			    UNION
				-- Always show the main project itself (it showing a single project, 0 otherwise)
				select	project_id from im_projects where project_id = :project_id
			    UNION
				-- Always show the list of selected projects to be shown
				select	p.project_id
				from	im_projects p
				where	(p.project_id in ([join [lappend project_id_list 0] ","])
					OR p.project_id = :project_id)
"

# ---------------------------------------------------------
# Build the main hierarchical SQL
# ---------------------------------------------------------

# The SQL is composed of the following elements:
#
# - The "parent" project, which contains the tree_sortkey information
#   that is necessary to determine its children.
#
# - The "children" project, which represents sub-projects
#   of "parent" of any depth.
#

set sort_integer 0
set sort_legacy  0
if { $list_sort_order=="name" } {
    set sort_order "lower(children.project_name)"
} elseif { $list_sort_order=="order" } {
    set sort_order "children.sort_order"
    set sort_integer 1
} elseif { $list_sort_order=="legacy" } {
    set sort_order "children.tree_sortkey" 
    set sort_legacy 1
} else {
    set sort_order "lower(children.project_nr)"
}

set sql "
	select
		parent.project_id as top_project_id,
		parent.parent_id as top_parent_id,
		children.parent_id as parent_id,
		children.project_id as project_id,
		children.project_nr as project_nr,
		children.project_name as project_name,
		children.project_status_id as project_status_id,
		children.project_type_id as project_type_id,
		im_category_from_id(children.project_status_id) as project_status,
		parent.project_id as parent_project_id,
		parent.project_nr as parent_project_nr,
		parent.project_name as parent_project_name,
		tree_level(children.tree_sortkey) -1 as subproject_level,
		substring(parent.tree_sortkey from 17) as parent_tree_sortkey,
		substring(children.tree_sortkey from 17) as child_tree_sortkey,
		$sort_order as sort_order
	from
		im_projects parent,
		im_projects children
	where
		parent.parent_id is null
		and children.tree_sortkey between 
			parent.tree_sortkey and 
			tree_right(parent.tree_sortkey)
		and parent.project_id in ($parent_project_sql)
		and children.project_id in ($child_project_sql)
	order by
		lower(parent.project_name),
		children.tree_sortkey
"


# ---------------------------------------------------------
# Select out the hours for the different projects and dates
#
# Effectively, we are replacing here an SQL join with a join
# over a TCL hash array. This simplifies the SQL and the TCL
# logic later.
# Also, there is a "LEFT OUTER" join logic, because we need
# to show the projects even if there are no hours available
# for them at that moment.
# ---------------------------------------------------------

set material_sql "
		,coalesce(h.material_id, :default_material_id) as material_id,
		(select material_name from im_materials m where m.material_id = h.material_id) as material
"
if {!$materials_p} { set material_sql "" }


set hours_sql "
	select
		h.hours,
		h.note,
		h.invoice_id,
		to_char(h.day, 'J') as julian_day,
		p.project_id
		$material_sql
	from
		im_hours h,
		($sql) p
	where
		h.project_id = p.project_id and
		h.user_id = :user_id_from_search and
		$h_day_in_dayweek
"
db_foreach hours_hash $hours_sql {

    set hours_hours($project_id-$julian_day) $hours
    set hours_note($project_id-$julian_day) $note
    if {"" != $invoice_id} {
        set hours_invoice($project_id-$julian_day) $invoice_id
    }

}

# ad_return_complaint 1 [join [db_list_of_lists hours_sql $hours_sql] "<br>"]
# ad_script_abort

# ---------------------------------------------------------
# Get the list of open projects with direct membership
# Task are all considered open
# ---------------------------------------------------------

set open_projects_sql "
	-- all open projects with direct membership
	select	p.project_id as open_project_id
	from	im_projects p,
		acs_rels r
	where	r.object_id_two = :user_id_from_search
		and r.object_id_one = p.project_id
		and p.project_status_id not in ($closed_stati_list)
    UNION
	-- all open projects and super-project where the user has logged hours.
	select	main_p.project_id
	from	im_hours h,
		im_projects p,
		im_projects main_p
	where	h.user_id = :user_id_from_search
		and $h_day_in_dayweek
		and h.project_id = p.project_id
		and p.tree_sortkey between
			main_p.tree_sortkey and
			tree_right(main_p.tree_sortkey)
		and main_p.project_status_id not in ($closed_stati_list)
"
array set open_projects_hash {}
db_foreach open_projects $open_projects_sql {
	set open_projects_hash($open_project_id) 1
}

#db_foreach sql $open_projects_sql { append result "$open_project_id\n"}
#ad_return_complaint 1 "<pre>$result</pre>"


# ---------------------------------------------------------
# Has-Children? This is used to disable super-projects with children
# ---------------------------------------------------------

if {!$log_hours_on_parent_with_children_p} {
    set has_children_sql "
        select  parent.project_id as parent_id,
		child.project_id as child_id
        from    im_projects parent,
		im_projects child
        where	child.parent_id = parent.project_id
		and parent.project_status_id not in ($closed_stati_list)
		and child.project_status_id not in ($closed_stati_list)
    "
    array set has_children_hash {}
    db_foreach has_children $has_children_sql {
        set has_children_hash($parent_id) 1
    }
}


# ---------------------------------------------------------
# Execute query and format results
# ---------------------------------------------------------

db_multirow hours_multirow hours_timesheet $sql

multirow_sort_tree hours_multirow project_id parent_id sort_order


# ---------------------------------------------------------
# Format the output
# ---------------------------------------------------------

# Don't show closed and deleted projects:
# The tree algorithm maintains a "closed_level"
# that determines the sub_level of the last closed
# intermediate project.

set results ""
set ctr 0
set nbsps "&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;"
set old_project_id 0
set closed_level 0
set closed_status [im_project_status_open]
set old_parent_project_nr ""


template::multirow foreach hours_multirow {

    # --------------------------------------------- 
    # Deal with the open and closed subprojects
    # A closed project will prevent all sub-projects from
    # being displayed. So it "leaves a trace" by setting
    # the "closed_level" to its's current level.
    # The "closed_status" will be reset to "open", as soon
    # as the next project reaches the same "closed_level".

    # Check for closed_p - if the project is in one of the closed states
    switch $task_visibility_scope {
	"main_project" {
	    # Membership is not necessary - just check status
	    set project_closed_p 0
	    if {[lsearch -exact $closed_stati $project_status_id] > -1} {
		set project_closed_p 1
	    }
	}
	"specified" {
	    # Membership is not necessary - just check status
	    set project_closed_p 0
	    if {[lsearch -exact $closed_stati $project_status_id] > -1} {
		set project_closed_p 1
	    }
	}
	"sub_project" {
	    # Control is with subprojects, tasks are always considered open.
	    set project_closed_p [expr 1-[info exists open_projects_hash($project_id)]]
	    if {$project_type_id == [im_project_type_task]} { set project_closed_p 0 }
	}
	"task" {
	    # Control is with each task individually
	    set project_closed_p [expr 1-[info exists open_projects_hash($project_id)]]
	}
    }

    # Change back from a closed branch to an open branch
    if {$subproject_level <= $closed_level} {
	ns_log Notice "new: action: reset to open"
	set closed_status [im_project_status_open]
	set closed_level 0
    }

    ns_log Notice "new: p=$project_id, depth=$subproject_level, closed_level=$closed_level, status=$project_status"


    # We've just discovered a status change from open to closed:
    # Remember at what level this has happened to undo the change
    # once we're at the same level again:
    if {$project_closed_p && $closed_status == [im_project_status_open]} {
	ns_log Notice "new: action: set to closed"
	set closed_status [im_project_status_closed]
	set closed_level $subproject_level
    }

#    We have moved the open/closed check to the display
#    routine below in order to show closed projects with
#    hours. 
#    if {$closed_status == [im_project_status_closed] } {
#	# We're below a closed project - skip this.
#	ns_log Notice "new: action: continue"
#	continue
#    }

    # ---------------------------------------------
    # Indent the project line
    #
    set indent ""
    set level $subproject_level
    while {$level > 0} {
	set indent "$nbsps$indent"
	set level [expr $level-1]
    }

    # ---------------------------------------------
    # These are the hours and notes captured from the intranet-timesheet2-task-popup 
    # modules, if it's there. The module allows the user to capture notes during the
    # day on what task she is working.
    set p_hours ""
    set p_notes ""
    if {[info exists popup_hours($project_id)]} { set p_hours $popup_hours($project_id) }
    if {[info exists popup_notes($project_id)]} { set p_notes $popup_notes($project_id) }


    # ---------------------------------------------
    # Insert intermediate header for every top-project
    if {$parent_project_nr != $old_parent_project_nr} { 
	set project_name "<b>$project_name</b>"
	set project_nr "<b>$project_nr</b>"

	# Add an empty line after every main project
	if {"" != $old_parent_project_nr} {
	    append results "<tr class=rowplain><td colspan=99>&nbsp;</td></tr>\n"
	}
	
	if {$debug} { append results "<tr class=rowplain><td>$parent_tree_sortkey</td><td>$parent_project_nr</td><td colspan=99>$parent_project_name</td></tr>\n" }
	set old_parent_project_nr $parent_project_nr
    }

    # ---------------------------------------------
    # Write out the HTML for logging hours
    set project_url [export_vars -base "/intranet/projects/view?" {project_id return_url}]
    append results "
	<tr $bgcolor([expr $ctr % 2])>"
    if {$debug} { append results "
	  <td>$child_tree_sortkey</td>
	  <td>$parent_project_nr</td>\n"
    }
    
    if {$show_project_nr_p} { set ptitle "$project_nr - $project_name" } else { set ptitle $project_name }

    set log_on_parent_p 1
    if {[info exists has_children_hash($project_id)]} { set log_on_parent_p 0 }

    # Write out the name of the project nicely indented
    append results "<td><nobr>$indent <A href=\"$project_url\">$ptitle</A></nobr></td>\n"

    set invoice_id 0
    set invoice_key "$project_id-$julian_date"
    if {[info exists hours_invoice($invoice_key)]} { set invoice_id $hours_invoice($invoice_key) }

    # Check if the current tree-branch-status is "closed"
    set closed_p [expr $closed_status == [im_project_status_closed]]

    if {"t" == $edit_hours_p && $log_on_parent_p && !$invoice_id && !$closed_p} {

	# Log hours on "Parent".
	if {!$show_week_p} {

	    # Daily View - 1 field for hours + 1 field for comment
	    set hours ""
	    set note ""
	    if {[info exists hours_hours($project_id-$julian_date)]} { set hours $hours_hours($project_id-$julian_date) }
	    if {[info exists hours_note($project_id-$julian_date)]} { set note $hours_note($project_id-$julian_date) }

	    append results "<td><INPUT NAME=hours0.$project_id size=5 MAXLENGTH=5 value=\"$hours\">$p_hours</td>\n"
	    append results "<td><INPUT NAME=notes0.$project_id size=40 value=\"[ns_quotehtml [value_if_exists note]]\">$p_notes</td>\n"
	    if {$materials_p} {
		append results "<td>[im_select -ad_form_option_list_style_p 1 materials0.$project_id $material_options $material_id]</td>\n"
	    }

	} else {

	    # Weekly View - 7 fields with hours only
	    foreach i $weekly_logging_days {
		set julian_day_offset [expr $julian_week_start + $i]
		set hours ""
		set note ""
		if {[info exists hours_hours($project_id-$julian_day_offset)]} { set hours $hours_hours($project_id-$julian_day_offset) }
		if {[info exists hours_note($project_id-$julian_day_offset)]} { set note $hours_note($project_id-$julian_day_offset) }
		append results "<td><INPUT NAME=hours${i}.$project_id size=5 MAXLENGTH=5 value=\"$hours\"></td>\n"
	    }

	}

    } else {

	# Just write plain text and no <input>, because the user shouldn't enter hours here.

	if {!$show_week_p} {

	    # Daily view with plain text, without <input>
	    set hours ""
	    set note ""
	    if {[info exists hours_hours($project_id-$julian_date)]} { set hours $hours_hours($project_id-$julian_date) }
	    if {[info exists hours_note($project_id-$julian_date)]} { set note $hours_note($project_id-$julian_date) }
	    
	    append results "
		<td>
			$hours
			<INPUT TYPE=HIDDEN NAME=hours0.$project_id value=\"$hours\">
		</td>
	    "
	    append results "
		<td>
			$note
			<INPUT TYPE=HIDDEN NAME=notes0.$project_id value=\"[ns_quotehtml [value_if_exists note]]\">
		</td>
	    "
	    if {$materials_p} {
		append results "<td>$material <input type=hidden name=materials0.$project_id value=$material_id></td>\n"
	    }


	    
	} else {
	    
	    # Weekly view with plain text only
	    foreach i $weekly_logging_days {
		set julian_day_offset [expr $julian_week_start + $i]
		set hours ""
		set note ""
		if {[info exists hours_hours($project_id-$julian_day_offset)]} { set hours $hours_hours($project_id-$julian_day_offset) }
		if {[info exists hours_note($project_id-$julian_day_offset)]} { set note $hours_note($project_id-$julian_day_offset) }
		append results "
			<td>
				$hours
				<INPUT TYPE=HIDDEN NAME=hours${i}.$project_id value=\"$hours\">
			</td>
		"
	    }
	}
    }
    append results "</tr>\n"
    incr ctr
}

if { [empty_string_p results] } {
    append results "
<tr>
  <td align=center><b>
    [_ intranet-timesheet2.lt_There_are_currently_n_1]<br>
    [_ intranet-timesheet2.lt_Please_notify_your_ma]
  </b></td>
</tr>\n"
}

set export_form_vars [export_form_vars julian_date user_id_from_search show_week_p]


# ---------------------------------------------------------
# Format the weekly column headers
# ---------------------------------------------------------

# Date format for formatting
set weekly_column_date_format "YYYY<br>MM-DD"

set week_header_html ""
foreach i $weekly_logging_days {

    set julian_day_offset [expr $julian_week_start + $i]

    set header_day_of_week [db_string day_of_week "select to_char(to_date($julian_day_offset, 'J'), 'Dy')"]
    set header_day_of_week_l10n [lang::message::lookup "" intranet-timesheet2.Day_of_week_$header_day_of_week $header_day_of_week]
    set header_date [db_string header "select to_char(to_date($julian_day_offset, 'J'), :weekly_column_date_format)"]

    append week_header_html "<th>$header_day_of_week_l10n<br>$header_date</th>\n"
}
