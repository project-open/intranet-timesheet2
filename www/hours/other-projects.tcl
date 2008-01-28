# /packages/intranet-timesheet2/www/hours/other-project.tcl
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
    Lets a user choose a project on which to log hours

    @param on_which_table table we're adding hours
    @param julian_date day in julian format for which we're adding hours
    @param user_id The user for which we're logging hours
 
    @author Michael Bryzek (mbryzek@arsdigita.com)
    @creation-date January, 2000
    @cvs-id other-projects.tcl,v 3.9.2.7 2000/09/22 01:38:38 kevin Exp
   
} {
    { julian_date "" } 
}

# ---------------------------------------------------------
# 
# ---------------------------------------------------------

set user_id [ad_maybe_redirect_for_registration]
set subsite_id [ad_conn subsite_id]

# Choose between daily/weekly time entry screen
if { [string compare [ad_parameter TimeEntryScreen "" "daily"] "weekly"] == 0 } {
    set target "time-entry"
} else {
    set target "new"
}
set page_title "[_ intranet-timesheet2.Choose_project]"
set context_bar [im_context_bar [list index?[export_url_vars on_which_table] [_ intranet-timesheet2.Hours]] [list $target?[export_url_vars julian_date] "[_ intranet-timesheet2.Add_hours]"] "[_ intranet-timesheet2.Choose_project]"]


# ---------------------------------------------------------
# 
# ---------------------------------------------------------

# Create a form to allow people to select multiple projects
set page_body "
<form method=post action=$target>
[export_form_vars user_id on_which_table julian_date]
<ul>
"


# Give the user a list of all the projects from which to choose
# Note that they have two ways to select a project:
#  1. Click the link for the group name to select one project
#  2. Checkoff a set of projects and hit the submit button at 
#     the end of the page

# ToDo: Decide and cleanup!!!

set sql "

select
	p.*
from
	(select
                p.project_id,
                r.member_p as permission_member,
                see_all.see_all as permission_all
        from
                im_projects p,
                (       select  count(rel_id) as member_p,
                                object_id_one as object_id
                        from    acs_rels
                        where   object_id_two = :user_id
                        group by object_id_one
                ) r,
                (       select  count(*) as see_all
                        from acs_object_party_privilege_map
                        where   object_id=:subsite_id
                                and party_id=:user_id
                                and privilege='view_projects_all'
                ) see_all
        where
                p.project_id = r.object_id
	 	and p.project_status_id in ([im_project_status_open])
	) perm,
	im_projects p
where
	p.project_id = perm.project_id
        and (
                perm.permission_member > 0
                or perm.permission_all > 0
        )
order by 
	upper(project_name)
"

db_foreach projects_list $sql {
    append page_body "
  <input type=checkbox name=project_id_list value=$project_id> 
  <a href=$target?on_what_id=$project_id&[export_url_vars on_which_table julian_date]>
    $project_nr - $project_name
  </a>
  <br>
"
} if_no_rows {
    # offer the user the option of adding a project. 
    # We set return url to this page
    set return_url [im_url_with_query]
    append page_body "<li> [_ intranet-timesheet2.lt_There_are_no_projects]"
}

append page_body "
</ul>

<p>
<center><input type=submit value=\" [_ intranet-timesheet2.lt_Log_hours_on_selected] \"></center>
</form>

"


#doc_return  200 text/html [im_return_template]

