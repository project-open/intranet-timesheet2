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

if {0 != $project_id} {

    # Project specified => only one project
    set one_project_only_p 1

    set project_sql "
	select	p.project_id
	from	im_projects p
	where 	p.project_id = :project_id
	order by upper(project_name)
    "

} elseif {"" != $project_id_list} {

    # An entire list of project has been selected
    set one_project_only_p 0

    set project_sql "
	select	p.project_id
	from	im_projects p 
	where	p.project_id in ([join $project_id_list ","])
		and p.parent_id is null
	order by upper(project_name)
    "

} else {

    # Project_id unknown => select all projects
    set one_project_only_p 0

    set project_sql "   
	select	p.project_id
	from	im_projects p,
		(	select 	r.object_id_one as project_id 
			from	im_projects p,
				acs_rels r
			where	r.object_id_one = p.project_id
				and object_id_two = :user_id
		    UNION
			select	project_id
			from	im_hours h
			where	h.user_id = :user_id
				and h.day = to_date(:julian_date, 'J')
		) r
	where 
		r.project_id =  p.project_id
		and p.parent_id is null
		and p.project_status_id not in (select * from im_sub_categories(81))
	order by upper(p.project_name)
    "
}


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
# - 

set sql "
select
	h.hours, 
	h.note, 
	h.billing_rate,
	parent.project_id as top_project_id,
        children.project_id as project_id,
        children.project_nr as project_nr,
        children.project_name as project_name,
        children.parent_id as parent_project_id,
	children.project_status_id as project_status_id,
	im_category_from_id(children.project_status_id) as project_status,
	parent.project_nr as parent_project_nr,
	parent.project_name as parent_project_name,
        tree_level(children.tree_sortkey) -1 as subproject_level
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
	children.tree_sortkey between 
		parent.tree_sortkey and 
		tree_right(parent.tree_sortkey)
        and parent.project_id in (
	    $project_sql
	)
order by
	lower(parent.project_name),
        children.tree_sortkey
"

# doesn't work, because it only supresses the child
# itself, but not the child's children (the entire
# branch).
set old_status_query "
	and children.project_status_id not in (
		[im_project_status_deleted],
		[im_project_status_canceled],
		[im_project_status_closed]
	)
"


# ---------------------------------------------------------
# Execute query and format results
# ---------------------------------------------------------

# Don't show closed and deleted projects:
# The tree algorithm maintains a "closed_level"
# that determines the sub_level of the last closed
# intermediate project.


# Determine all the members of the "closed" super-status
set closed_stati [db_list closed_stati "
	select	child_id
	from	im_category_hierarchy
	where	parent_id = 81
    UNION
	select	81 as child_id
"]


set results ""
set ctr 0
set nbsps "&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;"
set old_project_id 0
set closed_level 99
set closed_status [im_project_status_open]
db_foreach hours_timesheet $sql {

    ns_log Notice "timesheet2/hours: pid=$project_id, depth=$subproject_level, status=$project_status, closed_stati=$closed_stati"

    # ---------------------------------------------
    # Deal with the open and closed subprojects

    # Check for closed_p - if the project is in one of the closed states
    set project_closed_p 0
    if {[lsearch -exact $closed_stati $project_status_id] > -1} { 
	set project_closed_p 1
    }

    # We've just discovered a status change from open to closed:
    # Remember at what level this has happened to undo the change
    # once we're at the same level again:
    if {$project_closed_p && $closed_status == [im_project_status_open]} {
	ns_log Notice "timesheet2/hours: action: set to closed"
	set closed_status [im_project_status_closed]
	set closed_level $subproject_level
    }

    # Change back from a closed branch to an open branch
    if {$subproject_level == $closed_level && $project_status_id == [im_project_status_open] && $closed_status == [im_project_status_closed]} {
	ns_log Notice "timesheet2/hours: action: reset to open"
	set closed_status [im_project_status_open]
	set closed_level 99
    }

    if {$closed_status == [im_project_status_closed]} {
	# We're below a closed project - skip this.
	ns_log Notice "timesheet2/hours: action: continue"
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
    if {0 == $subproject_level} { 
	set project_name "<b>$project_nr - $project_name</b>"

	# Add an empty line after every main project
	if {"" == $parent_project_id} {
	    append results "<tr class=rowplain><td colspan=99>&nbsp;</td></tr>\n"
	}
    }

    # Allow hour logging
    set project_url [export_vars -base "/intranet/projects/view?" {project_id return_url}]
    append results "
	<tr $bgcolor([expr $ctr % 2])>
	  <td><nobr>$indent <A href=\"$project_url\">$project_name</A> $project_status</nobr></td>
	  <td><INPUT NAME=hours.$project_id size=5 MAXLENGTH=5 value=\"$hours\">$p_hours</td>
	  <td>
	    <INPUT NAME=notes.$project_id size=60 value=\"[ns_quotehtml [value_if_exists note]]\">
            $p_notes
	  </td>
	</tr>
    "
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

