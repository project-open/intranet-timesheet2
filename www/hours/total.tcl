# /packages/intranet-timesheet2/www/hours/total.tcl
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
	Shows total number of hours spent on all project

	@author Michael Bryzek (mbryzek@arsdigita.com)
	@creation-date Jan 2000
	@cvs-id total.tcl,v 3.7.2.6 2000/09/22 01:38:38 kevin Exp
} {

}


# ---------------------------------------------------------------
# Security & Defaults
# ---------------------------------------------------------------

set current_user_id [ad_maybe_redirect_for_registration]
if {![im_permission $current_user_id "view_hours_all"]} {
    ad_return_complaint 1 [lang::message::lookup "" intranet-timesheet2.Not_Allowed_to_see_hours "
    You are not allowed to see all timesheet hours in the system"]
    ad_script_abort
}


# ---------------------------------------------------------------
#
# ---------------------------------------------------------------


set page_title "[_ intranet-timesheet2.lt_Units_on_all_projects]"
set context_bar [im_context_bar "[_ intranet-timesheet2.lt_Units_on_all_projects]"]

set page_body "
[_ intranet-timesheet2.lt_Click_on_a_project_na]
<ul>
"


set sql "
select 
	p.project_id, 
	p.project_name, 
	round(sum(h.hours)) as total_hours,
	min(h.day) as first_day, 
	max(h.day) as last_day
from 
	im_hours h, 
	im_projects p
where 
	p.project_id = h.project_id
group by p.project_id, p.project_name
order by upper(p.project_name)
"

set none_found_p 1
db_foreach all_projects $sql {
	set none_found_p 0
        set first_day_str "[util_AnsiDatetoPrettyDate $first_day]"
        set last_day_str  "[util_AnsiDatetoPrettyDate $last_day]" 
	append page_body "<li><a href=one-project?project_id=$project_id&item=[ad_urlencode $project_name]>$project_name</A>, 
[_ intranet-timesheet2.lt_total_hours_units_bet_1]\n";
}

if {$none_found_p == 1} {
	append page_body "<em>[_ intranet-timesheet2.lt_No_time_logged_on_any]</em>"
}

append page_body "</UL>\n"



#doc_return  200 text/html [im_return_template]
