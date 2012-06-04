# /packages/intranet-timesheet2/www/hours/full.tcl
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
    Shows a detailed list of all the hours one user 
    spent on a given item (e.g. a project)

    @param project_id we are looking at
    @param user_id the user for whom we're viewing hours. Defaults to currently logged in user.
    @param item used only for UI
 
    @author Michael Bryzek (mbryzek@arsdigita.com)
    @cvs-id full.tcl,v 3.5.6.6 2000/09/22 01:38:37 kevin Exp
} {
    project_id:integer
    { user_id:integer "" }
    { item "" }
}


set current_user_id [ad_maybe_redirect_for_registration]

# Has the current user the right to edit all timesheet information?
set edit_timesheet_p [im_permission $current_user_id "add_hours_all"]
set view_ours_all_p [im_permission $current_user_id "view_hours_all"]
set view_finance_p [im_permission $current_user_id "view_finance"]


if {!$view_ours_all_p} {
    ad_return_complaint 1 "<li>[_ intranet-core.lt_You_have_insufficient_6]"
    ad_script_abort
}

set return_url [im_url_with_query]

if { [empty_string_p $user_id] && ($current_user_id != 0) } {
    set looking_at_self_p 1
    set user_id $current_user_id
} else {
    if {$current_user_id == $user_id} {
        set looking_at_self_p 1
    } else {
        set looking_at_self_p 0
    }
}

set user_name [db_string user_name "select im_name_from_user_id(:user_id) from dual"]

if { ![empty_string_p $item] } {
    set page_title "[_ intranet-timesheet2.lt_Units_on_item_by_user]"
} else {
    set page_title "[_ intranet-timesheet2.Units_by_user_name]"
}

set context_bar [im_context_bar [list projects "[_ intranet-timesheet2.View_employees_units]"] [list projects "[_ intranet-timesheet2.One_employee]"] "[_ intranet-timesheet2.One_project]"]

set page_body "<ul>\n"

set sql "
	select 
		to_char(day,'fmDay') as pretty_day_fmday,
		to_char(day,'fmMonth') as pretty_day_fmmonth,
		to_char(day,'fmDD') as pretty_day_fmdd,
		to_char(day,'YYYY') as pretty_day_year,
		to_char(day, 'J') as j_day,
		h.hours, 
		h.billing_rate,
		h.hours * h.billing_rate as amount_earned, 
		h.note,
		h.project_id as hours_project_id,
		c.currency
	from
		im_hours h,
		im_costs c
	where
		h.project_id in (
			select	children.project_id
			from	im_projects parent,
				im_projects children
			where
				children.tree_sortkey between
					parent.tree_sortkey
					and tree_right(parent.tree_sortkey)
				and parent.project_id = :project_id
			    UNION
				select :project_id as project_id
		)
		and h.user_id = :user_id
		and h.hours is not null
		and h.cost_id = c.cost_id
	order by day
"


set total_hours_on_project 0
set total_hours_billed_hourly 0
set hourly_bill 0

db_foreach hours_on_project $sql {
    set pretty_day "[_ intranet-timesheet2.$pretty_day_fmday], [_ intranet-timesheet2.$pretty_day_fmmonth] $pretty_day_fmdd $pretty_day_year"
    set note_url [export_vars -base "/intranet-timesheet2/hours/one" {{julian_date $j_day} user_id {project_id $hours_project_id} return_url}]

    set hours_units [_ intranet-timesheet2.hours_units]
    if {$edit_timesheet_p} {
        set hours_units "<a href=\"$note_url\">$hours_units</a>\n"
    }
    append page_body "<p><li>$pretty_day <br><em>$hours_units</em>\n"

    set total_hours_on_project [expr $total_hours_on_project + $hours]

    if {$view_finance_p && ![empty_string_p $amount_earned]} {
        append page_body " (${currency} [format %4.2f $billing_rate]/hour = ${currency} [format %4.2f $amount_earned])"
        set hourly_bill [expr $hourly_bill + $amount_earned]
        set total_hours_billed_hourly [expr $total_hours_billed_hourly + $hours]
    }

    if {$edit_timesheet_p} {
	set note "<a href=\"[export_vars -base "/intranet-timesheet2/hours/one" {{julian_date $j_day} user_id {project_id $hours_project_id} return_url}]\">$note</a>\n"
    }

    if ![empty_string_p $note] {
        append page_body "<blockquote>$note</blockquote>"
    }
}

append page_body "\n<br><br><b>[_ intranet-timesheet2.Total_1]</b> [util_commify_number $total_hours_on_project] [_ intranet-timesheet2.hours]"

if {$hourly_bill > 0} {
    set hours_var "[util_commify_number $total_hours_billed_hourly]"
    append page_body "<!--<br><br>[_ intranet-timesheet2.lt_hours_varof_those_uni] $[util_commify_number [format %4.2f $hourly_bill]]-->"
}

append page_body "</ul>\n"



#doc_return  200 text/html [im_return_template]
