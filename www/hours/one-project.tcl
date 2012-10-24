# /packages/intranet-timesheet2/www/hours/one-project.tcl
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
	Shows hours by all users for a specific item/project

	@param project_id row we're viewing hours against
	@param item used only for UI
 
	@author Michael Bryzek (mbryzek@arsdigita.com)
	@creation-date Jan 2000
	@cvs-id one-project.tcl,v 3.6.6.6 2000/09/22 01:38:38 kevin Exp
} {
	project_id:integer
	{ item "" }
}


set current_user_id [ad_maybe_redirect_for_registration]
set view_ours_all_p [im_permission $current_user_id "view_hours_all"]
if {!$view_ours_all_p} { 
    ad_return_complaint 1 "<li>[_ intranet-core.lt_You_have_insufficient_6]"
    ad_script_abort
}


set show_notes_p 1

set page_title "[_ intranet-timesheet2.Units]"
if { ![empty_string_p $item] } {
	append page_title " on $item"
}
set context_bar [im_context_bar [list total "[_ intranet-timesheet2.Project_units]"] "[_ intranet-timesheet2.Units_on_one_project]"]

set page_body "
[_ intranet-timesheet2.lt_Click_on_a_persons_na]
<ul>
"





set sql "
	select 
		u.user_id, 
		im_name_from_user_id(u.user_id) as  user_name,
		to_char(sum(h.hours),'999G999G999D99') as total_hours,
		min(day) as first_day,
		max(day) as last_day
	from 
		users u, 
		im_hours h
	where 
		u.user_id = h.user_id
		and h.project_id in (
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
	group by 
		u.user_id
	order by 
		upper(im_name_from_user_id(u.user_id))
"

db_foreach hours_on_one_projects $sql {
    set first_day_str "[util_AnsiDatetoPrettyDate $first_day]"
    set last_day_str "[util_AnsiDatetoPrettyDate $last_day]"
    append page_body "<li><a href='/intranet/users/view?user_id=$user_id'>$user_name</a>,<a href=full?[export_url_vars project_id user_id]&date=$last_day>[_ intranet-timesheet2.lt_total_hours_units_bet]</a>\n"
} if_no_rows {
	append page_body "<li>[_ intranet-timesheet2.lt_No_units_have_been_lo]\n"
}

append page_body "</ul>\n"
