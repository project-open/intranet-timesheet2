# /packages/intranet-timesheet2/www/hours/projects.tcl
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
    Shows all the hours an employee has worked, organized 
    by project
    
    @param user_id If specified, give them information for that user. Otherwise, send a list of users.

    @author mbryzek@arsdigita.com
    @creation-date Jan 2000

    @cvs-id projects.tcl,v 3.6.6.6 2000/09/22 01:38:38 kevin Exp
} {
    { user_id:integer "" }
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


if { [empty_string_p $user_id] } {
    # send them a list of users
    set page_title "[_ intranet-timesheet2.View_employees_hours]"
    set context_bar [im_context_bar "[_ intranet-timesheet2.View_employees_hours]"]
    set page_body "[_ intranet-timesheet2.lt_Choose_an_employee_to].<ul>"
    set rows_found_p 0

    set sql "
	select
		u.*,
		im_name_from_user_id(u.user_id) as user_name 
	from
		(select distinct user_id from im_hours) u
	where
		't' = acs_permission__permission_p(u.user_id, :current_user_id, 'read')
	order by user_name
    "

    db_foreach users_who_logged_hours $sql {
        append page_body "<li><a href=projects?[export_url_vars user_id]>$user_name</a>\n"
    } if_no_rows {
        append page_body "<em>[_ intranet-timesheet2.No_users_found]</em>"
    }

    append page_body "</ul>"

} else {
    
    if { ![db_0or1row user_name "select im_name_from_user_id(:user_id) as user_name from dual"] } {
        ad_return_error "[_ intranet-timesheet2.User_does_not_exist]" "[_ intranet-timesheet2.lt_User_user_id_does_not_1]"
	return
    }
	      
    set page_title "[_ intranet-timesheet2.Hours_by_user_name]"
    set context_bar [im_context_bar [list projects "[_ intranet-timesheet2.View_employees_hours]"] "[_ intranet-timesheet2.One_employee]"]

    # Click on a project name to see the full log for that project 
    set page_body "<ul>\n"

    set sql "
	select 
		p.project_name, 
		p.project_id,
		sum(h.hours) as total_hours,
		min(h.day) as first_day, 
		max(h.day) as last_day
	from 
		im_projects p,
		im_hours h
	where 
		p.project_id = h.project_id
		and h.user_id = :user_id
	group by 
		p.project_name, 
		p.project_id
    "

    db_foreach hours_on_project $sql {
	set first_day_str "[util_AnsiDatetoPrettyDate $first_day]"
	set last_day_str "[util_AnsiDatetoPrettyDate $last_day]"
        append page_body "<li><a href=full?project_id=$project_id&[export_url_vars user_id]&date=$last_day&item=[ad_urlencode $project_name]>$project_name</a>, [_ intranet-timesheet2.lt_total_hours_hours_bet]</em>"
    } if_no_rows {
        append page_body "<em>[_ intranet-timesheet2.lt_No_time_logged_on_any]</em>"
    }
    append page_body "</ul>"
}

 

#doc_return  200 text/html [im_return_template]
