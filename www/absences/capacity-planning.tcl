# /packages/intranet-timesheet2/www/absences/capacity-planning.tcl
#
# Copyright (C) 1998-2004 various parties
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
    Capacity planning 
    @author Klaus Hofeditz (klaus.hofeditz@project-open.com)

} {
    { order_by "Project nr" }
    { include_subprojects_p 0 }
    { project_status_id 0 }
    { project_type_id:integer 0 }
    { letter:trim "" }
    { month "" }
    { year "" }
    { start_idx:integer 0 }
    { how_many "" }
    { view_name "project_list" }
    { filter_advanced_p:integer 0 }
}


# for testing 
set cap_month 2
set cap_year 2010


# General settings
set show_context_help_p 0
set user_id [ad_maybe_redirect_for_registration]
set page_title "Capacity Planning"
set context [list "Permissions"]
set subsite_id [ad_conn subsite_id]
set context_bar [im_context_bar $page_title]
set url_stub [im_url_with_query]

# Please verify-might need adjustment
set im_absence_type_vacation 5000
set im_absence_type_personal 5001
set im_absence_type_sick 5002
set im_absence_type_travel 5003
set im_absence_type_bankholiday 5005 

# Date operations 
set first_day_of_month ""
append first_day_of_month $cap_year "-" $cap_month "-01"

set number_days_month ""
set number_days_month [db_string get_number_days_month "SELECT date_part('day','$first_day_of_month'::date + '1 month'::interval - '1 day'::interval)" -default 0]

set last_day_of_month ""
set last_day_of_month [db_string get_number_days_month "select to_date( '$cap_year' || '-' || '$cap_month' || '-' || '$number_days_month','yyyy-mm-dd')+1 from dual;" -default 0]

# set sql for top line (user and absences)
# workdays: total business days - absences - saturday/sunday - bank holidays

set title_sql "
	select 
		p.person_id, 
		p.first_names, 
		p.last_name,
			(select count(*) from (select * from im_absences_working_days_month(p.person_id,$cap_month,$cap_year) t(days int))ct) as 
		work_days,
			(select
                        	count(*)
	                from
        	                im_user_absences a,
                	        (select im_day_enumerator as d from im_day_enumerator(to_date('first_day_of_month','mm/dd/yyyy'), to_date('$last_day_of_month','yyyy-mm-dd'))) d
	                where
        	                a.start_date <=  to_date('$last_day_of_month','yyyy-mm-dd')::date and
                	        a.end_date >= to_date('$first_day_of_month','yyyy-mm-dd')::date and
                        	d.d between a.start_date and a.end_date and
				a.owner_id = p.person_id and
	                        a.absence_type_id = $im_absence_type_vacation) as 
		vacation_days 
	from 
		persons p,
		im_hours h

"

#	where 
#		p.person_id = 28467 or p.person_id = 28395

# ---------------------------------------------------------------
# Create table header
# ---------------------------------------------------------------

set table_header_html ""
append table_header_html "<table cellpadding='4' cellspacing='4' border='1'><tr>\n"

# ---------------------------------------------------------------
# Create top column (employees) 
# ---------------------------------------------------------------


set ctr 0 

append table_header_html "<td>ID:<br>"
append table_header_html "Name:<br>"
append table_header_html "Work Days:<br>"
append table_header_html "Vacation Days<br>"
append table_header_html "</td>"

db_foreach projects_info_query $title_sql  {
	append table_header_html "<td>"
	append table_header_html $person_id "<br>"
	append table_header_html $first_names "&nbsp;" "$last_name" "<br>"
	append table_header_html $work_days "<br>"
	append table_header_html $vacation_days
	append table_header_html "</td>"
	incr ctr
}



# ---------------------------------------------------------------
# Create table body
# ---------------------------------------------------------------
set table_body_html ""


# build sql 

# exclude deleted and closed projects 
set exclude_closed_projects [im_sub_categories [im_project_status_deleted] ]
set exclude_deleted_projects [im_sub_categories [im_project_status_closed]]
set exclude_status_id [concat $exclude_closed_projects $exclude_deleted_projects] 

# exclude sub-projects
set exclude_subprojects_p 1 

# do not exclude types 
set exclude_type_id ""

# do not exclude tasks
set exclude_tasks_p 1

set current_user_id [ad_get_user_id]
set max_project_name_len 50

set list_sort_order [parameter::get_from_package_key -package_key "intranet-timesheet2" -parameter TimesheetAddHoursSortOrder -default "name"]

# Handle subprojects


    # ---------------------------------------------------------
    # Compile "criteria"

    set p_criteria [list]
    set main_p_criteria [list]
    if {$exclude_subprojects_p} {
        lappend p_criteria "p.parent_id is null"
    }

    if {0 != $exclude_status_id && "" != $exclude_status_id} {
        lappend p_criteria "p.project_status_id not in ([join [im_sub_categories $exclude_status_id] ","])"
        lappend main_p_criteria "p.project_status_id not in ([join [im_sub_categories $exclude_status_id] ","])"
    }

    if {0 != $exclude_type_id && "" != $exclude_type_id} {
        lappend p_criteria "p.project_type_id not in ([join [im_sub_categories $exclude_type_id] ","])"
        # No restriction of type on parent project!
    }

    if {$exclude_tasks_p} {
        lappend p_criteria "p.project_type_id not in ([join [im_sub_categories [im_project_type_task]] ","])"
        # Main project is never of type task...
    }

    if {0 != $project_type_id && "" != $project_type_id} {
        lappend p_criteria "p.project_type_id in ([join [im_sub_categories $project_type_id] ","])"
        # No restriction on parent's project type!
    }

    # -----------------------------------------------------------------
    # Compose the SQL

    set where_clause [join $p_criteria " and\n\t\t\t\t\t"]
    if { ![empty_string_p $where_clause] } {
        set where_clause " and $where_clause"
    }

    switch $list_sort_order {
        name { set sort_order "lower(p.project_name)" }
        order { set sort_order "p.sort_order" }
        legacy { set sort_order "p.tree_sortkey" }
        default { set sort_order "lower(p.project_nr)" }
    }
    set sql "
                select
                        p.project_id,
                        substring(p.project_name for :max_project_name_len) as project_name_shortened
		from
			im_projects p
                where
                        p.parent_id is null
			$where_clause

                order by
                        p.project_name
    "

    set options [list]
    db_foreach project_name $sql {
	append table_body_html "<tr><td>$project_name_shortened</td></tr>"
    }



# ---------------------------------------------------------------
# Create table footer
# ---------------------------------------------------------------

append table_footer_html "</tr></table>\n"





# ---------------------
# final standard stuff
# ---------------------

set filter_html "
<form method=get name=projects_filter action='/intranet/projects/index'>
[export_form_vars start_idx order_by how_many view_name include_subprojects_p letter]

<table border=0 cellpadding=0 cellspacing=1>
"


if {[im_permission $user_id "view_projects_all"]} {
    append filter_html "
  <tr>
    <td class=form-label>[_ intranet-core.Project_Status]:</td>
    <td class=form-widget>[im_category_select -include_empty_p 1 "Intranet Project Status" project_status_id $project_status_id]</td>
  </tr>
    "
}


append filter_html "
  <tr>
<td class=form-label>[_ intranet-core.Start_Date]</td>
            <td class=form-widget>
              <input type=textfield name=cap_month value=$cap_month>
            </td>
  </tr>
  <tr>
<td class=form-label>[lang::message::lookup "" intranet-core.End_Date "End Date"]</td>
            <td class=form-widget>
              <input type=textfield name=cap_year value=$cap_year>
            </td>
  </tr>
"
append filter_html "
  <tr>
    <td class=form-label></td>
    <td class=form-widget>
          <input type=submit value='[lang::message::lookup "" intranet-core.Action_Go "Go"]' name=submit>
    </td>
  </tr>
"

append filter_html "</table>\n</form>\n"

# Left Navbar is the filter/select part of the left bar
set left_navbar_html "
        <div class='filter-block'>
                <div class='filter-title'>
                   #intranet-core.Filter_Projects#
                </div>
                $filter_html
        </div>
      <hr/>
"

append left_navbar_html "
        <div class='filter-block'>
        <div class='filter-title'>
            #intranet-core.Admin_Projects#
        </div>
        </div>
"


