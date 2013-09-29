# /packages/intranet-timesheet2/www/weekly_report.tcl
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

# ---------------------------------------------------------------
# Page Contract
# ---------------------------------------------------------------

ad_page_contract {
    Shows a summary of the loged hours by all team members of a project (1 week).
    Only those users are shown that:
    - Have the permission to add hours or
    - Have the permission to add absences AND
	have atleast some absences logged

    @param owner_id	user concerned can be specified
    @param project_id	can be specified
    @param workflow_key workflow_key to indicate if hours have been confirmed      

    @author Malte Sussdorff (malte.sussdorff@cognovis.de)
} {
    { owner_id:integer "" }
    { project_id:integer "" }
    { cost_center_id:integer "" }
    { end_date "" }
    { start_date "" }
    { approved_only_p:integer "0"}
    { workflow_key ""}
    { view_name "hours_list" }
    { view_type "html" }
    { dimension "hours" }
    { order_by "username,project_name"}
}

# ---------------------------------------------------------------
# Defaults & Security
# ---------------------------------------------------------------

set user_id [ad_maybe_redirect_for_registration]
set admin_p [im_is_user_site_wide_or_intranet_admin $user_id]
set subsite_id [ad_conn subsite_id]
set site_url "/intranet-timesheet2"
set return_url "$site_url/cw_hours_report"
set date_format "YYYY-MM-DD"

# We need to set the overall hours per week an employee is working
# Make this a default for all for now.
set hours_per_week [expr 5 * [parameter::get -parameter TimesheetHoursPerDay]] 

if {"" == $start_date} { 
    set start_date [db_string get_today "select to_char(sysdate,'YYYY-01-01') from dual"]   
}

if {"" == $end_date} { 
    # if no end_date is given, set it to six weeks in the future
    set end_date [db_string current_week "select to_char(sysdate + interval '6 weeks',:date_format) from dual"]
}


if {![im_permission $user_id "view_hours_all"] && $owner_id == ""} {
    set owner_id $user_id
}

# Get the correct view options
# set view_options [db_list_of_lists views {select view_label,view_name from im_views where view_type_id = 1451}]
set view_options {{Hours hours_list}}

# Allow the project_manager to see the hours of this project
if {"" != $project_id} {
    set manager_p [db_string manager "select count(*) from acs_rels ar, im_biz_object_members bom where ar.rel_id = bom.rel_id and object_id_one = :project_id and object_id_two = :user_id and object_role_id = 1301" -default 0]
    if {$manager_p || [im_permission $user_id "view_hours_all"]} {
	set owner_id ""
    }
}

# Allow the manager to see the department
if {"" != $cost_center_id} {
    set manager_id [db_string manager "select manager_id from im_cost_centers where cost_center_id = :cost_center_id" -default ""]
    if {$manager_id == $user_id || [im_permission $user_id "view_hours_all"]} {
        set owner_id ""
    }
}

if { $project_id != "" } {
    set error_msg [lang::message::lookup "" intranet-core.No_name_for_project_id "No Name for project %project_id%"]
    set project_name [db_string get_project_name "select project_name from im_projects where project_id = :project_id" -default $error_msg]
}

# ---------------------------------------------------------------
# Format the Filter and admin Links
# ---------------------------------------------------------------

set form_id "report_filter"
set action_url "/intranet-timesheet2/cw_hours_report"
set form_mode "edit"
if {[im_permission $user_id "view_projects_all"]} {
    set project_options [im_project_options -include_empty 1 -exclude_subprojects_p 0 -include_empty_name [lang::message::lookup "" intranet-core.All "All"]]
} else {
    set project_options [im_project_options -include_empty 0 -exclude_subprojects_p 0 -include_empty_name [lang::message::lookup "" intranet-core.All "All" -member_user_id $user_id]]
}

set company_options [im_company_options -include_empty_p 1 -include_empty_name "[_ intranet-core.All]" -type "CustOrIntl" ]
set levels {{"#intranet-timesheet2.lt_hours_spend_on_projec#" "project"} {"#intranet-timesheet2.lt_hours_spend_on_project_and_sub#" subproject} {"#intranet-timesheet2.hours_spend_overall#" all}}


ad_form \
    -name $form_id \
    -action $action_url \
    -mode $form_mode \
    -method GET \
    -export {start_at duration} \
    -form {
    }

if {[apm_package_installed_p intranet-timesheet2-workflow]} {
    ad_form -extend -name $form_id -form {
	{approved_only_p:text(select),optional {label \#intranet-timesheet2.OnlyApprovedHours\# ?} {options {{[_ intranet-core.Yes] "1"} {[_ intranet-core.No] "0"}}} {value 0}}
    }
}

ad_form -extend -name $form_id -form {
    {project_id:text(select),optional {label \#intranet-cost.Project\#} {options $project_options} {value $project_id}}
}

# Deal with the department
if {[im_permission $user_id "view_hours_all"]} {
    set cost_center_options [im_cost_center_options -include_empty 1 -include_empty_name [lang::message::lookup "" intranet-core.All "All"] -department_only_p 0]
} else {
    # Limit to Cost Centers where he is the manager
    set cost_center_options [im_cost_center_options -include_empty 1 -department_only_p 1 -manager_id $user_id]
}

if {"" != $cost_center_options} {
    ad_form -extend -name $form_id -form {
        {cost_center_id:text(select),optional {label "User's Department"} {options $cost_center_options} {value $cost_center_id}}
    }
}

ad_form -extend -name $form_id -form {
    {dimension:text(select) {label "Dimension"} {options {{Hours hours} {Percentage percentage}}} {value $dimension}}
    {view_type:text(select) {label "Type"} {options {{HTML html} {Excel xls}}} {value $view_type}}
    {start_date:text(text) {label "[_ intranet-timesheet2.Start_Date]"} {value "$start_date"} {html {size 10}} {after_html {<input type="button" style="height:20px; width:20px; background: url('/resources/acs-templating/calendar.gif');" onclick ="return showCalendar('start_date', 'y-m-d');" >}}}
    {end_date:text(text) {label "[_ intranet-timesheet2.End_Date]"} {value "$end_date"} {html {size 10}} {after_html {<input type="button" style="height:20px; width:20px; background: url('/resources/acs-templating/calendar.gif');" onclick ="return showCalendar('end_date', 'y-m-d');" >}}}
    {view_name:text(select) {label \#intranet-core.View_Name\#} {value "$view_name"} {options $view_options}}
}

eval [template::adp_compile -string {<formtemplate id="$form_id" style="tiny-plain-po"></formtemplate>}]
set filter_html $__adp_output

# ---------------------------------------------------------------
# 3. Defined Table Fields
# ---------------------------------------------------------------

# Define the column headers and column contents that 
# we want to show:
#

im_view_set_def_vars -view_name $view_name -array_name "view_arr" -order_by $order_by -url "[export_vars -base "hours_report" -url {owner_id project_id cost_center_id end_date start_date approved_only_p workflow_key view_name view_type dimension}]"

set __column_defs ""
set __header_defs ""
foreach column_header $view_arr(column_headers) {
    append __column_defs "<table:table-column table:style-name=\"co1\" table:default-cell-style-name=\"ce3\"/>\n"
    append __header_defs " <table:table-cell office:value-type=\"string\"><text:p>$column_header</text:p></table:table-cell>\n"
}


# ---------------------------------------------------------------
# Get the Column Headers and prepare some SQL
# ---------------------------------------------------------------

set table_header_html "<tr><td class=rowtitle>[_ intranet-timesheet2.Users]</td><td class=rowtitle>[_ intranet-core.Project]</td>"

# Prepare the weeks headers

# Get the first and last week
#set start_week [db_string start_week "select extract(week from to_date(:start_date,'YYYY-MM-DD')) from dual"]
#set end_week [db_string end_week "select extract(week from to_date(:end_date,'YYYY-MM-DD')) from dual"]

set current_date $start_date
set weeks [list]
while {$current_date<=$end_date} {
    set current_week [db_string end_week "select extract(week from to_date(:current_date,'YYYY-MM-DD')) from dual"]   
    lappend view_arr(column_headers) $current_week
    lappend view_arr(column_headers_pretty) $current_week
    lappend weeks $current_week
    set current_date [db_string current_week "select to_char(to_date(:current_date,'YYYY-MM-DD') + interval '1 week','YYYY-MM-DD') from dual"]
    # for XLS output
    if {"percentage" == $dimension} {
	append __column_defs "<table:table-column table:style-name=\"co2\" table:default-cell-style-name=\"ce6\"/>\n"
    } else {
	append __column_defs "<table:table-column table:style-name=\"co2\" table:default-cell-style-name=\"ce5\"/>\n"
    }
    append __header_defs " <table:table-cell office:value-type=\"string\"><text:p>$current_week</text:p></table:table-cell>\n"
}

if {[llength $weeks]>52} {
    # We can't handle more than one year horizont
    ad_return_error "Problem with your input" "More than 52 weeks horizont is not supported."
}

# ---------------------------------------------------------------
# Get the Data and fill it up into lists
# ---------------------------------------------------------------

# Filter by owner_id
if {$owner_id != ""} {
    lappend view_arr(extra_wheres) "h.user_id = :owner_id"
}    

# Filter for projects
if {$project_id != ""} {
    # Get all hours for this project, including hours logged on
    # tasks (100) or tickets (101)
    lappend view_arr(extra_wheres) "(h.project_id in (	
              	   select p.project_id
		   from im_projects p, im_projects parent_p
                   where parent_p.project_id = :project_id
                   and p.tree_sortkey between parent_p.tree_sortkey and tree_right(parent_p.tree_sortkey)
                   and p.project_status_id not in (82)
		))"
}

# Filter for department_id
if { "" != $cost_center_id } {
        lappend view_arr(extra_wheres) "
        h.user_id in (select employee_id from im_employees where department_id in (select object_id from acs_object_context_index where ancestor_id = $cost_center_id) or h.user_id = :user_id)
"
}

im_view_process_def_vars -array_name view_arr


set table_body_html ""

# Get the username / project combinations
set user_projects [list]

set possible_projects_sql " (select distinct user_id,project_id from im_hours)"

# For XLS
set __output $__column_defs
# Set the first row
append __output "<table:table-row table:style-name=\"ro1\">\n$__header_defs</table:table-row>\n"

db_foreach projects_info_query "
    select username,project_name,personnel_number,p.project_id,employee_id,project_nr,company_id
    $view_arr(extra_selects_sql)
    from im_projects p, im_employees e, users u,$possible_projects_sql h
    $view_arr(extra_froms_sql)
    where u.user_id = h.user_id
    and p.project_id = h.project_id
    and e.employee_id = h.user_id
    and p.project_type_id not in (100,101)
    $view_arr(extra_wheres_sql)
    group by username,project_name,personnel_number,employee_id,p.project_id,project_nr,company_id
    $view_arr(extra_group_by_sql)
    order by $order_by
" {
    set user_project "${employee_id}-${project_id}"
    lappend user_projects $user_project
    set table_body($user_project) ""
    set xls_body($user_project) ""
    foreach column_var $view_arr(column_vars) {
	# HTML
	append table_body($user_project) "<td>[expr $column_var]</td>"

	# and XLS
	append xls_body($user_project) " <table:table-cell office:value-type=\"string\"><text:p>[expr $column_var]</text:p></table:table-cell>\n"
    }
}


# Now go for the extra data

# If we want the percentages, we need to 
# Load the total hours a user has logged in case we are looking at the
# actuals or forecast

# Approved comes from the category type "Intranet Timesheet Conf Status"
if {$approved_p && [apm_package_installed_p "intranet-timesheet2-workflow"]} {
    set hours_sql "select sum(hours) as total, extract(week from day) as week, user_id
	from im_hours, im_timesheet_conf_objects tco
        where tco.conf_id = im_hours.conf_object_id and tco.conf_status_id = 17010
        and day between :start_date and :end_date
	group by user_id, week"
} else {
    set hours_sql "select sum(hours) as total, extract(week from day) as week, user_id
	from im_hours
        where day between :start_date and :end_date
	group by user_id, week"
}

if {"percentage" == $dimension} {
    db_foreach logged_hours $hours_sql {
	if {$user_id != "" && $week != ""} {
	    set user_hours_${week}_${user_id} $total
	}
    }
}


foreach user_project $user_projects {
    set ttt [split $user_project "-"]
    set employee_id [lindex $ttt 0]
    set project_id [lindex $ttt 1]
    
    # Try to avoid building an array
    # Loop through all the column headers and set them to ""
    foreach week $weeks {
	set $week ""
	set planned($week) "0"
    }
    
    # Now load all the weeks variables
    # We need to differentiate by the view type to know where we get
    # the values from

    # get the hours only
    db_foreach weeks_info {select sum(hours) as sum_hours, extract(week from day) as week
    		from im_hours
		where user_id = :employee_id
                and project_id in (	
              	   select p.project_id
		   from im_projects p, im_projects parent_p
                   where parent_p.project_id = :project_id
                   and p.tree_sortkey between parent_p.tree_sortkey and tree_right(parent_p.tree_sortkey)
                   and p.project_status_id not in (82)
		)		   
		group by week
    } {
	if {"percentage" == $dimension} {
	    if {[info exists user_hours_${week}_$employee_id]} {
		set total [set user_hours_${week}_$employee_id]
	    } else {
		set total 0
	    }
	    if {0 < $total} {
		set $week "[expr round($sum_hours / $total *100)]"
	    } 
	} else {
	    set $week $sum_hours
	}
    }


    # Now append the values
    foreach week $weeks {
	if {"percentage" == $dimension} {
	    if {"" != [set $week]} {
		set value [set $week]
		append table_weeks($user_project) "<td>${value}%</td>"
		set xls_value [expr $value / 100.0]
	    } else {
		set value ""
		set xls_value ""
		append table_weeks($user_project) "<td></td>"
	    }
	    append xls_weeks($user_project) "<table:table-cell office:value-type=\"percentage\" office:value=\"$xls_value\"></table:table-cell>"
	} else {
	    set value [set $week]
	    append table_weeks($user_project) "<td>${value}</td>"
	    append xls_weeks($user_project) "<table:table-cell office:value-type=\"float\" office:value=\"$value\"></table:table-cell>"
	}
    }
}


# Now loop again through the user_projects so we can build up the
# table_html

foreach user_project $user_projects {
    # Get the non value columns
    append table_body_html "<tr>
      $table_body($user_project)
      $table_weeks($user_project)
      </tr>
    "
    append __output "<table:table-row table:style-name=\"ro1\">\n"
    append __output $xls_body($user_project)
    append __output $xls_weeks($user_project)
    append __output "\n</table:table-row>\n"
}   

if {"xls" == $view_type} {
    # Check if we have the table.ods file in the proper place
    set ods_file "[acs_package_root_dir "intranet-openoffice"]/templates/table.ods"
    if {![file exists $ods_file]} {
        ad_return_error "Missing ODS" "We are missing your ODS file $ods_file . Please make sure it exists"
    }
    set table_name "weekly_hours"
    intranet_oo::parse_content -template_file_path $ods_file -output_filename "weekly_hours.xls"
    ad_script_abort

} else {
    set table_header_html $view_arr(table_header_html)
    set left_navbar_html "
            <div class=\"filter-block\">
                $filter_html
            </div>
    "
}