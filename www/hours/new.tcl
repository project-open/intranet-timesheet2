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
}

# ---------------------------------------------------------
# Default & Security
# ---------------------------------------------------------

set debug 0

set user_id [ad_maybe_redirect_for_registration]
if {"" == $return_url} { set return_url [im_url_with_query] }
set bgcolor(0) " class=roweven "
set bgcolor(1) " class=rowodd "
if { [empty_string_p $julian_date] } {
    set julian_date [db_string sysdate_as_julian "select to_char(sysdate,'J') from dual"]
}
set project_id_for_default $project_id
if {0 == $project_id} { set project_id_for_default ""}

# "Log hours for a different day"
set different_date_url "index?[export_ns_set_vars url [list julian_date]]"

# "Log hours for a different project"
#    ad_return_complaint 1 [array get has_children_hash]

#    ad_return_complaint 1 [array get has_children_hash]

set different_project_url "other-projects?[export_url_vars julian_date]"

# Log Absences
set absences_url [export_vars -base "/intranet-timesheet2/absences/new" {return_url}]
set absences_link_text [lang::message::lookup "" intranet-timesheet2.Log_Absences "Log Absences"]


db_1row user_name_and_date "
select 
	im_name_from_user_id(user_id) as user_name,
	to_char(to_date(:julian_date, 'J'), 'fmDay fmMonth fmDD, YYYY') as pretty_date
from	users
where	user_id = :user_id" 

set page_title "[_ intranet-timesheet2.lt_Hours_for_pretty_date]"
set context_bar [im_context_bar [list index "[_ intranet-timesheet2.Hours]"] "[_ intranet-timesheet2.Add_hours]"]

set permissive_logging [parameter::get_from_package_key -package_key intranet-timesheet2 -parameter PermissiveHourLogging -default "permissive"]

set log_hours_on_potential_project_p [parameter::get_from_package_key -package_key intranet-timesheet2 -parameter TimesheetLogHoursOnPotentialProjectsP -default 1]

set list_sort_order [parameter::get_from_package_key -package_key "intranet-timesheet2" -parameter TimesheetAddHoursSortOrder -default "order"]

set show_project_nr_p [parameter::get_from_package_key -package_key "intranet-core" -parameter ShowProjectNrAndProjectNameP -default 0]

# Should we allow users to log hours on a parent project, even though it has children?
set log_hours_on_parent_with_children_p [parameter::get_from_package_key -package_key "intranet-core" -parameter LogHoursOnParentWithChildrenP -default 1]

# Determine how to show the tasks of projects. There are several options:
#	- main_project: The main project determines the subproject/task visibility space
#	- sub_project: Each (sub-) project determines the visibility of its tasks
#	- task: Each task has its own space - the user needs to be member of all tasks to log hours.
set task_visibility_scope [parameter::get_from_package_key -package_key "intranet-core" -parameter TimesheetTaskVisibilityScope -default "sub_project"]

# What is a closed status?
set closed_stati_select "select * from im_sub_categories([im_project_status_closed])"
if {!$log_hours_on_potential_project_p} {
    append closed_stati_select " UNION select * from im_sub_categories([im_project_status_potential])"
}


# ---------------------------------------------------------
# Logic to check if the user is allowed to log hours
# ---------------------------------------------------------

set edit_hours_p "t"

# When should we consider the last month to be closed?
set last_month_closing_day [parameter::get_from_package_key -package_key intranet-timesheet2 -parameter TimesheetLastMonthClosingDay -default 0]


if {0 != $last_month_closing_day && "" != $last_month_closing_day} {

    # Check that $julian_date is before the Nth of the next month:
    # Select the 1st day of the last month:
    set first_of_last_month [db_string last_month "
	select to_char(now()::date - :last_month_closing_day::integer + '0 Month'::interval, 'YYYY-MM-01')
    "]
    set edit_hours_p [db_string e "select to_date(:julian_date, 'J') >= :first_of_last_month::date"]

}

set edit_hours_closed_message [lang::message::lookup "" intranet-timesheet2.Logging_hours_has_been_closed "Logging hours for this date has already been closed. Please contact your supervisor or the HR department."]


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
		and p.user_id = :user_id
		and q.user_id = :user_id
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
# ad_return_complaint 1 [array get popup_hours]


# ---------------------------------------------------------
# Build the SQL Subquery, determining the (parent)
# projects to be displayed 
# ---------------------------------------------------------

# Remove funny "{" or "}" characters in list
regsub -all {[\{\}]} $project_id_list "" project_id_list

# ad_return_complaint 1 $project_id

if {0 != $project_id} {

    # Project specified => only one project
    set one_project_only_p 1

    set project_sql "
	select	:project_id::integer
    "

} elseif {"" != $project_id_list} {

    # An entire list of project has been selected
    set one_project_only_p 0

    set project_sql "
	select	p.project_id
	from	im_projects p 
	where	p.project_id in ([join $project_id_list ","])
		and p.parent_id is null
    "

} else {

    # Project_id unknown => select all projects
    set one_project_only_p 0

    set project_sql "   
	select	p.project_id
	from	im_projects p
	where 
		p.parent_id is null
		and p.project_id in (
				select	r.object_id_one
				from	acs_rels r
				where	r.object_id_two = :user_id
			    UNION
				select	project_id
				from	im_hours h
				where	h.user_id = :user_id
					and h.day = to_date(:julian_date, 'J')
		)
		and p.project_status_id not in ([join [im_sub_categories [im_project_status_closed]] ","])
    "
}

# Determine how to show the tasks of projects.
switch $task_visibility_scope {
    "main_project" {
	# main_project: The main project determines the subproject/task visibility space
	set task_visibility_sql "
				select	sub.project_id
				from	acs_rels r,
					im_projects main,
					im_projects sub
				where	r.object_id_two = :user_id
					and r.object_id_one = main.project_id
					and main.tree_sortkey = tree_ancestor_key(sub.tree_sortkey, 1)
					and main.project_status_id not in ([join [im_sub_categories [im_project_status_closed]] ","])
					and sub.project_status_id not in ([join [im_sub_categories [im_project_status_closed]] ","])
	"
    }
    "sub_project" {
	# sub_project: Each (sub-) project determines the visibility of its tasks.
	# So we are looking for the "lowest" in the project hierarchy subproject
	# that's just above its tasks and controls the visibility of the tasks.
	# There are four conditions to get the list of the "controlling" projects quickly:
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
			and ctrl.project_status_id not in ([join [im_sub_categories [im_project_status_closed]] ","])
			and task.project_status_id not in ([join [im_sub_categories [im_project_status_closed]] ","])
			and r.object_id_one = ctrl.project_id
			and r.object_id_two = :user_id
	"

	set task_visibility_sql "
				-- Select any subprojects of control projects
				select	sub.project_id
				from	im_projects main,
					($ctrl_projects_sql) ctrl,
					im_projects sub
				where	ctrl.project_id = main.project_id
					and main.project_status_id not in ([join [im_sub_categories [im_project_status_closed]] ","])
					and sub.project_status_id not in ([join [im_sub_categories [im_project_status_closed]] ","])
					and sub.tree_sortkey between
						main.tree_sortkey and
						tree_right(main.tree_sortkey)
			UNION
				-- Select any project or task with explicit membership
				select  r.object_id_one
				from    acs_rels r
				where   r.object_id_two = :user_id
			UNION
				-- Select projects or tasks where the user has logged hours today
				select  project_id
				from    im_hours h
				where   h.user_id = :user_id
					and h.day = to_date(:julian_date, 'J')
	"

    }
    "task" {
	# task: Each task has its own space - the user needs to be member of all tasks to log hours.
	set task_visibility_sql "
				-- Show sub-project/tasks only with direct membership
				select	r.object_id_one
				from	acs_rels r
				where	r.object_id_two = :user_id
	"
    }
}


set children_sql "
				$task_visibility_sql
			    UNION
				-- Always show projects and tasks where user has logged hours
				select	project_id
				from	im_hours h
				where	h.user_id = :user_id
					and h.day = to_date(:julian_date, 'J')
			    UNION
				-- Always show the main project itself (it showing a single project, 0 otherwise)
				select	project_id from im_projects where project_id = :project_id
			    UNION
				-- Always show the list of selected projects to be shown
				select	p.project_id
				from	im_projects p
				where	p.project_id in ([join [lappend project_id_list 0] ","])
					and p.parent_id is null
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
		h.hours, 
		h.note, 
		h.billing_rate,
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
		left outer join (
				select	* 
				from	im_hours h
				where	h.day = to_date(:julian_date, 'J')
					and h.user_id = :user_id	
			) h 
			on (h.project_id = children.project_id)
	where
		parent.parent_id is null
		and children.tree_sortkey between 
			parent.tree_sortkey and 
			tree_right(parent.tree_sortkey)
		and parent.project_id in ($project_sql)
		and children.project_id in ($children_sql)
	order by
		lower(parent.project_name),
		children.tree_sortkey
"

# ---------------------------------------------------------
# Get the list of open projects with direct membership
# Task are all considered open
# ---------------------------------------------------------

set open_projects_sql "
	select	p.project_id as open_project_id
	from	im_projects p,
		acs_rels r
	where	r.object_id_two = :user_id
		and r.object_id_one = p.project_id
		and p.project_status_id not in ([join [im_sub_categories [im_project_status_closed]] ","])
"
array set open_projects_hash {}
db_foreach open_projects $open_projects_sql {
	set open_projects_hash($open_project_id) 1
}


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
		and parent.project_status_id not in ([join [im_sub_categories [im_project_status_closed]] ","])
		and child.project_status_id not in ([join [im_sub_categories [im_project_status_closed]] ","])
    "
    array set has_children_hash {}
    db_foreach has_children $has_children_sql {
        set has_children_hash($parent_id) 1
    }
}


# ---------------------------------------------------------
# Execute query and format results
# ---------------------------------------------------------

# Don't show closed and deleted projects:
# The tree algorithm maintains a "closed_level"
# that determines the sub_level of the last closed
# intermediate project.


# Determine all the members of the "closed" super-status
set closed_stati [db_list closed_stati $closed_stati_select]

set results ""
set ctr 0
set nbsps "&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;"
set old_project_id 0
set closed_level 0
set closed_status [im_project_status_open]
set old_parent_project_nr ""

db_multirow hours_multirow hours_timesheet $sql

# ad_return_complaint 1 "$sort_legacy $sort_integer"


multirow_sort_tree hours_multirow project_id parent_id sort_order

#if ($sort_legacy==0) {
#    if {$sort_integer} {
#	multirow_sort_tree -integer hours_multirow project_id parent_id sort_order
#    } else {
#	multirow_sort_tree hours_multirow project_id parent_id sort_order
#    }
#}

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

    if {$closed_status == [im_project_status_closed] } {
	# We're below a closed project - skip this.
	ns_log Notice "new: action: continue"
	continue
    }

    # ---------------------------------------------
    # Indent the project line
    set indent ""
    set level $subproject_level
    while {$level > 0} {
	set indent "$nbsps$indent"
	set level [expr $level-1]
    }

    # These are the hours and notes captured from the intranet-timesheet2-task-popup 
    # modules, if it's there. The module allows the user to capture notes during the
    # day on what task she is working.
    set p_hours ""
    set p_notes ""
    if {[info exists popup_hours($project_id)]} { set p_hours $popup_hours($project_id) }
    if {[info exists popup_notes($project_id)]} { set p_notes $popup_notes($project_id) }


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

    # Allow hour logging
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

    if {"t" == $edit_hours_p && $log_on_parent_p} {
	append results "
	  <td><nobr>$indent <A href=\"$project_url\">$ptitle</A></nobr></td>
	  <td><INPUT NAME=hours.$project_id size=5 MAXLENGTH=5 value=\"$hours\">$p_hours</td>
	  <td>
	    <INPUT NAME=notes.$project_id size=60 value=\"[ns_quotehtml [value_if_exists note]]\">
	    $p_notes
	  </td>
	"
    } else {
	if {"" == $hours} { set hours "" }
	append results "
	  <td><nobr>$indent <A href=\"$project_url\">$ptitle</A></nobr></td>
	  <td align=right>$hours</td>
	  <td>[value_if_exists note] $p_notes</td>
	"
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

set export_form_vars [export_form_vars julian_date return_url]

