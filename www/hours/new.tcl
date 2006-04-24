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
    set statement_name "hours_for_one_group"

    set project_sql "
	select
		p.project_id
	from 
		im_projects p
	where 
		p.project_id = :project_id
	order by 
		upper(project_name)
    "

} elseif {"" != $project_id_list} {

    # An entire list of project has been selected
    set one_project_only_p 0
    set statement_name "hours_for_one_group"

    set project_sql "
	select
		p.project_id
	from 
		im_projects p 
	where 
		p.project_id in ([join $project_id_list ","])
		and p.parent_id is null
	order by 
		upper(project_name)
    "

} else {

    # Project_id unknown => select all projects
    set one_project_only_p 0
    set statement_name "hours_for_groups"

    set project_sql "   
	select
		p.project_id
	from 
		im_projects p,
		(   select 
			r.object_id_one as project_id 
		    from 
			im_projects p,
			acs_rels r,
			im_categories psc
		    where
			r.object_id_one = p.project_id
			and object_id_two = :user_id
			and p.project_status_id = psc.category_id
			and upper(psc.category) not in (
			    'CLOSED','INVOICED','PARTIALLY PAID',
	                    'DECLINED','DELIVERED','PAID','DELETED','CANCELED'
	        )
		UNION
		    select
			project_id
		    from
			im_hours h
		    where
			h.user_id = :user_id
			and h.day = to_date(:julian_date, 'J')
		) r
	where 
		r.project_id =  p.project_id
		and p.parent_id is null
	order by 
		upper(p.project_name)
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
	and children.project_status_id not in (
		[im_project_status_deleted],
		[im_project_status_canceled],
		[im_project_status_closed]
	)
order by
	lower(parent.project_name),
        children.tree_sortkey
"

# ---------------------------------------------------------
# Execute query and format results
# ---------------------------------------------------------

set results ""
set ctr 0
set nbsps "&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;"
set old_project_id 0
db_foreach $statement_name $sql {

    set indent ""
    set level $subproject_level
    while {$level > 0} {
        set indent "$nbsps$indent"
	set level [expr $level-1]
    }

    # Highlight main projects
    if {0 == $subproject_level} { set project_name "<b>$project_name</b>" }

    # These are the hours and notes captured from the intranet-timesheet2-task-popup 
    # modules, if it's there. The module allows the user to capture notes during the
    # day on what task she is working.
    set p_hours ""
    set p_notes ""
    if {[info exists popup_hours($project_id)]} { set p_hours $popup_hours($project_id) }
    if {[info exists popup_notes($project_id)]} { set p_notes $popup_notes($project_id) }


    # Insert intermediate header for every parent_project
    if {$old_project_id != $top_project_id} {

	# Add an empty line after every main project
	if {"" == $parent_project_id} {
	    append results "<tr class=rowplain><td colspan=99>&nbsp;</td></tr>\n"
	}
    
	# Add a line for a project. This is useful if there are
	# no timesheet_tasks yet for this project, because we
	# always want to allow employees to log their ours in
	# order not to give them excuses.
	#
	append resultssss "
	<tr $bgcolor([expr $ctr % 2])>
	  <td>
	    <nobr>
	      $indent i
	      <A href=/intranet/projects/view?project_id=$project_id>
	        <B>$project_name</B>
	      </A>
	    </nobr>
	    <input type=hidden name=\"project_ids.$ctr\" value=\"$project_id\">
	    <input type=hidden name=\"timesheet_task_ids.$ctr\" value=\"\$task_id\">
	  </td>
	  <td></td>
	  <td>&nbsp;</td>
 	  <td>&nbsp;</td>
	</tr>
	"
	set old_project_id $top_project_id
	incr ctr
    }
    
  

    # Don't show the empty tasks that are produced with each project
    # due to the "left outer join" SQL query
    append results "
	<tr $bgcolor([expr $ctr % 2])>
	  <td>
	    <nobr>
	      $indent
	      <A href=/intranet-timesheet2-tasks/new?[export_url_vars task_id project_id return_url]>
	        $project_name
	      </A>
	    </nobr>
	    <input type=hidden name=\"project_ids.$ctr\" value=\"$project_id\">
	    <input type=hidden name=\"timesheet_task_ids.$ctr\" value=\"$project_id\">
	  </td>
	  <td>
	    <INPUT NAME=hours.$ctr size=5 MAXLENGTH=5 value=\"$hours\">
            $p_hours
	  </td>
	  <td>
	    <INPUT NAME=notes.$ctr size=60 value=\"[ns_quotehtml [value_if_exists note]]\">
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


