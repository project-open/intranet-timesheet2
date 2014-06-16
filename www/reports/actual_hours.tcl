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
    { display_type "html" }
    { dimension "hours" }
    { order_by "username,project_name"}
    { timescale "weekly" }
}

# ---------------------------------------------------------------
# Defaults & Security
# ---------------------------------------------------------------

set user_id [ad_maybe_redirect_for_registration]
set admin_p [im_is_user_site_wide_or_intranet_admin $user_id]
set subsite_id [ad_conn subsite_id]
set site_url "/intranet-timesheet2"
set return_url "actual_hours"
set date_format "YYYY-MM-DD"

# We need to set the overall hours per week an employee is working
# Make this a default for all for now.
set hours_per_week [expr 5 * [parameter::get -parameter TimesheetHoursPerDay]] 

if {"" == $start_date} { 
    set start_date [db_string get_today "select to_char(sysdate - interval '2 months','YYYY-MM-01') from dual"]   
}

if {"" == $end_date} { 
    # if no end_date is given, set it to six weeks in the future
    set end_date [db_string current_week "select to_char(sysdate + interval '6 weeks',:date_format) from dual"]
}

if {![im_permission $user_id "view_hours_all"] && $owner_id == ""} {
    set owner_id $user_id
}

# Get the correct view options
# set view_options [db_list_of_lists views {select view_label,view_name from im_views where display_type_id = 1451}]
set view_options {{Hours hours_list}}

# Allow the project_manager to see the hours of this project
# Project_id 0 is reserved for aggregation of hours on a user level
# only
set filter_project_id $project_id
if {"" != $project_id && $project_id != 0} {
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

if { $project_id != "" && $project_id != 0} {
    set error_msg [lang::message::lookup "" intranet-core.No_name_for_project_id "No Name for project %project_id%"]
    set project_name [db_string get_project_name "select project_name from im_projects where project_id = :project_id" -default $error_msg]
}

# ---------------------------------------------------------------
# Format the Filter and admin Links
# ---------------------------------------------------------------

set form_id "report_filter"
set action_url "actual_hours"
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

set project_options [concat [list [list None 0]] $project_options]
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
    {timescale:text(select) {label "Timescale"} {options {{Weekly weekly} {Monthly monthly}}} {value $timescale}}
    {display_type:text(select) {label "Type"} {options {{HTML html} {Excel xls}}} {value $display_type}}
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

im_view_set_def_vars -view_name $view_name -array_name "view_arr" -order_by $order_by -url "[export_vars -base "hours_report" -url {owner_id project_id cost_center_id end_date start_date approved_only_p workflow_key view_name display_type dimension}]"

set __column_defs ""
set __header_defs ""
foreach column_header $view_arr(column_headers) {
    append __column_defs "<table:table-column table:style-name=\"co1\" table:default-cell-style-name=\"ce3\"/>\n"
    append __header_defs " <table:table-cell office:value-type=\"string\"><text:p>$column_header</text:p></table:table-cell>\n"
}


# ---------------------------------------------------------------
# Get the Column Headers and prepare some SQL
# ---------------------------------------------------------------

# Prepare the timescale headers
# Those can be week numbers or months
set timescale_headers [list]
set fix_years [list]

set end_date_list [split $end_date "-"]
set end_year [lindex $end_date_list 0]
set end_month [lindex $end_date_list 1]
if {[string length $end_month] eq 1 } {
    set end_month "0$end_month"
}
set end_day [lindex $end_date_list 2]
if {[string length $end_day] eq 1 } {
    set end_day "0$end_day"
}

set end_date "${end_year}-${end_month}-${end_day}"

set start_date_list [split $start_date "-"]
set start_year [lindex $start_date_list 0]
set start_month [lindex $start_date_list 1]
if {[string length $start_month] eq 1 } {
    set start_month "0$start_month"
}
set start_day [lindex $start_date_list 2]
if {[string length $start_day] eq 1 } {
    set start_day "0$start_day"
}

set start_date "${start_year}-${start_month}-${start_day}"
set current_date $start_date

switch $timescale {
    weekly {
	while {$current_date<=$end_date} {
	    db_1row end_week "select extract(week from to_date(:current_date,'YYYY-MM-DD')) as week, extract(isoyear from to_date(:current_date,'YYYY-MM-DD')) as year"
	    set current_week "$week-$year"
	    lappend timescale_headers $current_week
	    set current_date [db_string current_week "select to_char(to_date(:current_date,'YYYY-MM-DD') + interval '1 week','YYYY-MM-DD') from dual"]
	}
	set timescale_sql "extract(week from day) || '-' || extract(isoyear from day)"
    }
    default {
	while {$current_date<=$end_date} {
	    set current_month [db_string end_week "select to_char(to_date(:current_date,'YYYY-MM-DD'),'YYMM') from dual"]   
	    lappend timescale_headers $current_month
	    set current_date [db_string current_month "select to_char(to_date(:current_date,'YYYY-MM-DD') + interval '1 month','YYYY-MM-DD') from dual"]
	}
	set timescale_sql "to_char(day,'YYMM')"
    }
}

# ---------------------------------------------------------------
# Get the Data and fill it up into lists
# ---------------------------------------------------------------

# Filter by owner_id
if {$owner_id != ""} {
    lappend view_arr(extra_wheres) "h.user_id = :owner_id"
}    

# Filter for projects
if {$project_id != "" && $project_id != 0} {
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

# Initialize the timescale headers for XLS output

set table_header_html $view_arr(table_header_html)

foreach timescale_header $timescale_headers {
    append table_header_html "<td class=rowtitle>$timescale_header</td>"
    # for XLS output
    if {"percentage" == $dimension} {
	append __column_defs "<table:table-column table:style-name=\"co2\" table:default-cell-style-name=\"ce6\"/>\n"
    } else {
	append __column_defs "<table:table-column table:style-name=\"co2\" table:default-cell-style-name=\"ce5\"/>\n"
    }
    append __header_defs " <table:table-cell office:value-type=\"string\"><text:p>$timescale_header</text:p></table:table-cell>\n"
}


set table_body_html ""

set possible_projects_sql " (select distinct user_id,project_id from im_hours)"

# For XLS
set __output $__column_defs
# Set the first row
append __output "<table:table-row table:style-name=\"ro1\">\n$__header_defs</table:table-row>\n"

set user_list [list]
db_foreach projects_info_query "
    select username,project_name,personnel_number,p.project_id,employee_id,project_nr,company_id, p.project_type_id
    $view_arr(extra_selects_sql)
    from im_projects p, im_employees e, users u,$possible_projects_sql h
    $view_arr(extra_froms_sql)
    where u.user_id = h.user_id
    and p.project_id = h.project_id
    and e.employee_id = h.user_id
    $view_arr(extra_wheres_sql)
    group by username,project_name,personnel_number,employee_id,p.project_id,project_nr,company_id, p.project_type_id
    $view_arr(extra_group_by_sql)
    order by $order_by
" {
    #  If we have a ticket or a task we should not show this as a potential project in the report
    # Therefore we will search for the parent_id which must be a project.
    if {$project_type_id eq 100 || $project_type_id eq 101} {
        # Task or ticket, aggregate
        set project_id [db_string parent "select parent_id from im_projects where project_id = :project_id" -default $project_id]
    }
    if {[lsearch $user_list $employee_id] < 0} {
        lappend user_list $employee_id
        set user_pretty($employee_id) $username_pretty
        set user_projects($employee_id) [list]
    }
    lappend user_projects($employee_id) $project_id
    set user_project "${employee_id}-${project_id}"
    set table_body($user_project) ""
    set xls_body($user_project) ""
    foreach column_var $view_arr(column_vars) {
        # HTML
        append table_body($user_project) "<td>[expr $column_var]</td>"

        # and XLS
        append xls_body($user_project) " <table:table-cell office:value-type=\"string\"><text:p>[expr $column_var]</text:p></table:table-cell>\n"
    }
}


foreach user_id $user_list {
    # Go through all the users to get their full list of projects
    
    if {$filter_project_id == 0} {
	# Get the user total line over all projects
	# Approved comes from the category type "Intranet Timesheet Conf Status"
	if {$approved_only_p && [apm_package_installed_p "intranet-timesheet2-workflow"]} {
	    set timescale_value_sql "select sum(hours) as sum_hours,$timescale_sql as timescale_header
 	        from im_hours, im_timesheet_conf_objects tco
                where tco.conf_id = im_hours.conf_object_id and tco.conf_status_id = 17010
		and user_id = :user_id
		group by timescale_header
                order by timescale_header
         "
	} else {
	    set timescale_value_sql "select sum(hours) as sum_hours,$timescale_sql as timescale_header
    		from im_hours
		where user_id = :user_id
		group by timescale_header
                order by timescale_header
         "
	}
	
	# Get the non value columns
	append __output "<table:table-row table:style-name=\"ro1\">\n"
	append table_body_html "<tr>"
	set parent_project ""
	set project_name ""
	
	# Append the values for an empty project
	# Get the most common names
	set username_pretty $user_pretty($user_id)
	foreach column_var $view_arr(column_vars) {
	    set column_value [expr $column_var]
	    # HTML
	    append table_body_html "<td>$column_value</td>"
	    # and XLS
	    append __output " <table:table-cell office:value-type=\"string\"><text:p>$column_value</text:p></table:table-cell>\n"
	}
	
	# Now create the actual rows
	foreach timescale_header $timescale_headers {
	    set var ${user_id}($timescale_header)	   
	    if {[info exists $var]} {
		set value [set $var]
	    } else {
		set value ""
	    }
	    if {"percentage" == $dimension} {
		if {$value == ""} {set value 0}
		append table_body_html "<td>${value}%</td>"
		set xls_value [expr $value / 100.0]
		append __output "<table:table-cell office:value-type=\"percentage\" office:value=\"$xls_value\"></table:table-cell>"
	    } else {
		append table_body_html "<td>${value}</td>"
		append __output "<table:table-cell office:value-type=\"float\" office:value=\"$value\"></table:table-cell>"
	    }
	}
	append table_body_html "</tr>"
	append __output "\n</table:table-row>\n"
	
    } else {
	# Go through all the users to get their full list of projects
	set user_projects($user_id) [im_parent_projects -project_ids $user_projects($user_id)] 
	foreach project_id  $user_projects($user_id) {
	    
	    # Get the timescale values for all projects, sorted by the
	    # tree_sortkey, so we can change traverse the projects correctly.
	    
	    # Approved comes from the category type "Intranet Timesheet Conf Status"
	    if {$approved_only_p && [apm_package_installed_p "intranet-timesheet2-workflow"]} {
            set timescale_value_sql "select sum(hours) as sum_hours,$timescale_sql as timescale_header
 	                                   from im_hours, im_timesheet_conf_objects tco
                                      where tco.conf_id = im_hours.conf_object_id and tco.conf_status_id = 17010
                                        and user_id = :user_id
                                        and project_id in (	
                                                select p.project_id
                                                from im_projects p, im_projects parent_p
                                                where parent_p.project_id = :project_id
                                                and p.tree_sortkey between parent_p.tree_sortkey and tree_right(parent_p.tree_sortkey)
                                                and p.project_status_id not in (82)
                                            )		   
                                   group by timescale_header
                                   order by timescale_header
         "
	    } else {
		set timescale_value_sql "select sum(hours) as sum_hours,$timescale_sql as timescale_header
    		from im_hours
		where user_id = :user_id
                and project_id in (	
              	   select p.project_id
		   from im_projects p, im_projects parent_p
                   where parent_p.project_id = :project_id
                   and p.tree_sortkey between parent_p.tree_sortkey and tree_right(parent_p.tree_sortkey)
                   and p.project_status_id not in (82)
		)		   
		group by timescale_header
                order by timescale_header
         "
	    }
	    
	    # Store the value for the timescale for the project in an array
	    # for later use.
	    db_foreach timescale_info $timescale_value_sql {
		set var ${user_id}_${project_id}($timescale_header)
		if {"percentage" == $dimension} {
		    if {[info exists user_hours_${timescale_header}_$employee_id]} {
			set total [set user_hours_${timescale_header}_$employee_id]
		    } else {
			set total 0
		    }
		    if {0 < $total} {
			set $var "[expr round($sum_hours / $total *100)]"
		    } else {
			set $var "0"
		    }
		} else {
		    set $var $sum_hours
		}
	    }
	    
	    # Get the non value columns
	    append __output "<table:table-row table:style-name=\"ro1\">\n"
	    append table_body_html "<tr>"
	    db_1row project_info "select parent_id, im_name_from_id(parent_id) as parent_project, project_name from im_projects where project_id = :project_id"
	    # Append the values for an empty project
	    # Get the most common names
	    set username_pretty $user_pretty($user_id)
	    foreach column_var $view_arr(column_vars) {
		set column_value [expr $column_var]
		# HTML
		append table_body_html "<td>$column_value</td>"
		# and XLS
		append __output " <table:table-cell office:value-type=\"string\"><text:p>$column_value</text:p></table:table-cell>\n"
	    }
	    
	    # Now create the actual rows
	    foreach timescale_header $timescale_headers {
		set var ${user_id}_${project_id}($timescale_header)	   
		if {[info exists $var]} {
		    set value [set $var]
		} else {
		    set value ""
		}
		if {"percentage" == $dimension} {
		    if {$value == ""} {set value 0}
		    append table_body_html "<td>${value}%</td>"
		    set xls_value [expr $value / 100.0]
		    append __output "<table:table-cell office:value-type=\"percentage\" office:value=\"$xls_value\"></table:table-cell>"
		} else {
		    append table_body_html "<td>${value}</td>"
		    append __output "<table:table-cell office:value-type=\"float\" office:value=\"$value\"></table:table-cell>"
		}
	    }
	    append table_body_html "</tr>"
	    append __output "\n</table:table-row>\n"
	}   
    }
}


if {"xls" == $display_type} {
    # Check if we have the table.ods file in the proper place
    set ods_file "[acs_package_root_dir "intranet-openoffice"]/templates/table.ods"
    if {![file exists $ods_file]} {
        ad_return_error "Missing ODS" "We are missing your ODS file $ods_file . Please make sure it exists"
    }
    set table_name "weekly_hours"
    intranet_oo::parse_content -template_file_path $ods_file -output_filename "weekly_hours.xls"
    ad_script_abort

} else {
    set left_navbar_html "
            <div class=\"filter-block\">
                $filter_html
            </div>
    "
}