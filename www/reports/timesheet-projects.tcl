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
    { filter_project_id:integer "" }
    { cost_center_id:integer "" }
    { end_date "" }
    { start_date "" }
    { approved_only_p:integer "0"}
    { workflow_key ""}
    { view_name "timesheet_projects_list" }
    { detail_level "summary"}
    { dimension "hours" }
    { order_by "user_name,project_name"}
    { display_type "html" }
    { timescale "weekly" }
}

# ---------------------------------------------------------------
# Defaults & Security
# ---------------------------------------------------------------

set current_user_id [ad_maybe_redirect_for_registration]
set admin_p [im_is_user_site_wide_or_intranet_admin $current_user_id]
set subsite_id [ad_conn subsite_id]
set site_url "/intranet-timesheet2"
set return_url "timesheet-projects"
set date_format "YYYY-MM-DD"
set name_order [parameter::get -package_id [apm_package_id_from_key intranet-core] -parameter "NameOrder" -default 1]

# We need to set the overall hours per month an employee is working
# Make this a default for all for now.
set hours_per_month [expr [parameter::get -parameter TimesheetWorkDaysPerYear] * [parameter::get -parameter TimesheetHoursPerDay] / 12] 
set hours_per_absence [parameter::get -package_id [apm_package_id_from_key intranet-timesheet2] -parameter "TimesheetHoursPerAbsence" -default 8.0]

if {"" == $start_date} { 
    set start_date [db_string get_today "select to_char(sysdate - interval '10 weeks',:date_format) from dual"]
}

if {"" == $end_date} { 
    # if no end_date is given, set it to six months in the future
    set end_date [db_string current_month "select to_char(sysdate + interval '1 week',:date_format) from dual"]
}

# ---------------------------------------------------------------
# This report only offers users and projects
# Redirect to a user only report if no projects are given
# ---------------------------------------------------------------

if {$filter_project_id eq "" && $detail_level eq "single"} {
#    ad_returnredirect [export_vars -base "/intranet-reporting/timesheet-incomplete-days" -url {start_date end_date cost_center_id}]
    set detail_level "summary"
}


# Get the first and last month
set start_month [db_string start_month "select to_char(to_date(:start_date,'YYYY-MM-DD'),'YYMM') from dual"]
set end_month [db_string end_month "select to_char(to_date(:end_date,'YYYY-MM-DD'),'YYMM') from dual"]


if {![im_permission $current_user_id "view_hours_all"] && $owner_id == ""} {
    set owner_id $current_user_id
}

# Get the correct view options
# set view_options [db_list_of_lists views {select view_label,view_name from im_views where view_type_id = 1451}]
set view_options {{#intranet-core.Projects# timesheet_projects_list}}

# Allow the project_manager to see the hours of this project
if {"" != $filter_project_id} {
    set filter_project_ids [im_parent_projects -project_ids $filter_project_id]
    set manager_p [db_string manager "select count(*) from acs_rels ar, im_biz_object_members bom where ar.rel_id = bom.rel_id and object_id_one 
        in ([template::util::tcl_to_sql_list $filter_project_ids]) and object_id_two = :current_user_id and object_role_id = 1301" -default 0]
    if {$manager_p || [im_permission $current_user_id "view_hours_all"]} {
        	set owner_id ""
    }
}

# Allow the manager to see the department
if {"" != $cost_center_id} {
    set manager_p [im_manager_of_cost_center_p -user_id $current_user_id -cost_center_id $cost_center_id]
    if {$manager_p || [im_permission $current_user_id "view_hours_all"]} {
        set owner_id ""
    }
}

if { $filter_project_id != "" } {
#    set error_msg [lang::message::lookup "" intranet-core.No_name_for_project_id "No Name for project %filter_project_id%"]
    set error_msg ""
    set project_name [db_string get_project_name "select project_name from im_projects where project_id = :filter_project_id" -default $error_msg]
}

# ---------------------------------------------------------------
# Format the Filter and admin Links
# ---------------------------------------------------------------

set form_id "report_filter"
set action_url "timesheet-projects"
set form_mode "edit"

if {[im_permission $current_user_id "view_hours_all"]} {
    set project_options [im_project_options -include_empty 1 -exclude_subprojects_p 0 -include_empty_name [lang::message::lookup "" intranet-core.All "All"]]
} else {
    set project_options [im_project_options -include_empty 1 -exclude_subprojects_p 0 -include_empty_name [lang::message::lookup "" intranet-core.All "All"] -pm_user_id $current_user_id]
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
    {filter_project_id:text(select),optional {label \#intranet-cost.Project\#} {options $project_options} {value $filter_project_id}}
}

# Deal with the department
if {[im_permission $current_user_id "view_hours_all"]} {
    set cost_center_options [im_cost_center_options -include_empty 1 -include_empty_name [lang::message::lookup "" intranet-core.All "All"] -department_only_p 0]
} else {
    # Limit to Cost Centers where he is the manager
    set cost_center_options [im_cost_center_options -include_empty 1 -department_only_p 1 -manager_id $current_user_id]
}

if {"" != $cost_center_options} {
    ad_form -extend -name $form_id -form {
        {cost_center_id:text(select),optional {label "[_ intranet-core.Department]"} {options $cost_center_options} {value $cost_center_id}}
    }
}

ad_form -extend -name $form_id -form {
    {dimension:text(select) {label "[_ intranet-timesheet2.Dimension]"} {options {{[_ intranet-timesheet2.Hours] hours} {[_ intranet-timesheet2.Percentage] percentage}}} {value $dimension}}
    {timescale:text(select) {label "[_ intranet-timesheet2.Timescale]"} {options {{[_ intranet-timesheet2.Daily] daily} {[_ intranet-timesheet2.Weekly] weekly} {[_ intranet-timesheet2.Monthly] monthly}}} {value $timescale}}
    {detail_level:text(select) {label "[_ intranet-timesheet2.Detail_Level]"} {options {{[_ intranet-timesheet2.Single] single} {[_ intranet-timesheet2.Subprojects] summary} {[_ intranet-timesheet2.Detailed] detailed}}} {value $detail_level}}
    {with_absences_p:text(checkbox),optional {label "[_ intranet-timesheet2.WithAbsencesP]"} {options {{"" 1}}}}
    {start_date:text(text) {label "[_ intranet-timesheet2.Start_Date]"} {value "$start_date"} {html {size 10}} {after_html {<input type="button" style="height:20px; width:20px; background: url('/resources/acs-templating/calendar.gif');" onclick ="return showCalendar('start_date', 'y-m-d');" >}}}
    {end_date:text(text) {label "[_ intranet-timesheet2.End_Date]"} {value "$end_date"} {html {size 10}} {after_html {<input type="button" style="height:20px; width:20px; background: url('/resources/acs-templating/calendar.gif');" onclick ="return showCalendar('end_date', 'y-m-d');" >}}}
    {view_name:text(select) {label \#intranet-core.View_Name\#} {value "$view_name"} {options $view_options}}
    {display_type:text(select) {label "[_ intranet-core.Type]"} {options {{HTML html} {Excel xls}}} {value $display_type}}
} -on_request {
    set with_absences_p 0
}

eval [template::adp_compile -string {<formtemplate id="$form_id" style="tiny-plain-po"></formtemplate>}]
set filter_html $__adp_output

# ---------------------------------------------------------------
# 3. Defined Table Fields
# ---------------------------------------------------------------

# Define the column headers and column contents that 
# we want to show:
#

im_view_set_def_vars -view_name $view_name -array_name "view_arr" -order_by $order_by -url "[export_vars -base "hours_report" -url {owner_id project_id cost_center_id end_date start_date approved_only_p workflow_key view_name dimension display_type}]"

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
    daily {
        while {$current_date<=$end_date} {
            set current_day [db_string end_week "select to_char(to_date(:current_date,'YYYY-MM-DD'),'DD-MM') from dual"]   
            lappend timescale_headers $current_day
            set current_date [db_string current_week "select to_char(to_date(:current_date,'YYYY-MM-DD') + interval '1 day','YYYY-MM-DD') from dual"]
        }
        set timescale_sql "to_char(day,'DD-MM')"
    }
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
if {$filter_project_id != ""} {
    # Get all hours for this project, including hours logged on
    # tasks (100) or tickets (101)
    lappend view_arr(extra_wheres) "(h.project_id in (	
        select p.project_id
		from   im_projects p, im_projects parent_p
        where  parent_p.project_id = :filter_project_id
        and    p.tree_sortkey between parent_p.tree_sortkey and tree_right(parent_p.tree_sortkey)
        and    p.project_status_id not in (82)
		))"
}

# Filter for department_id
if { "" != $cost_center_id } {
    set cost_center_list [im_cost_center_options -parent_id $cost_center_id]
    set cost_center_ids [list $cost_center_id]
    foreach cost_center $cost_center_list {
        lappend cost_center_ids [lindex $cost_center 1]
    }
    lappend view_arr(extra_wheres) "
        h.user_id in (select employee_id from im_employees where department_id in ([template::util::tcl_to_sql_list $cost_center_ids]) or h.user_id = :current_user_id)
"
}

# ---------------------------------------------------------------
# Prepare the headers in HTML & XLS
# ---------------------------------------------------------------

im_view_process_def_vars -array_name view_arr
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

# For XLS
set __output $__column_defs
# Set the first row
append __output "<table:table-row table:style-name=\"ro1\">\n$__header_defs</table:table-row>\n"

# ---------------------------------------------------------------
#  Define the calculation for the hours based on detail level 
#  and approval
# ---------------------------------------------------------------

    
set possible_projects_sql " (select distinct user_id,project_id from (select user_id,p.project_id from im_hours h, im_projects p where p.project_id=h.project_id and p.project_type_id not in (100,101) UNION select user_id,parent_id from im_hours h, im_projects p where p.project_id = h.project_id and p.project_type_id in (100,101) ) possi)"

set user_list [list]
set project_ids [list]
db_foreach projects_info_query "select im_name_from_user_id(employee_id, $name_order) as user_name,project_name,personnel_number,p.project_id,employee_id,h.user_id,project_nr,company_id, project_type_id
$view_arr(extra_selects_sql)
from im_projects p, im_employees e, users u,$possible_projects_sql h
$view_arr(extra_froms_sql)
where u.user_id = h.user_id
and p.project_id = h.project_id
and e.employee_id = h.user_id
$view_arr(extra_wheres_sql)
group by username,project_name,personnel_number,employee_id,h.user_id,p.project_id,project_nr,company_id, project_type_id
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
        set user_projects($employee_id) [list]
    }
    lappend user_projects($employee_id) $project_id
    lappend project_ids $project_id
}


set project_ids [lsort -unique $project_ids] 

switch $detail_level {
    single {
        if {$filter_project_id ne ""} {
            set project_ids $filter_project_id
            set subproject_sql "and project_id in (	
                                    select p.project_id
                                    from im_projects p, im_projects parent_p
                                    where parent_p.project_id = :project_id
                                    and p.tree_sortkey between parent_p.tree_sortkey and tree_right(parent_p.tree_sortkey)
                                    and p.project_status_id not in (82)
                                )"
        } else {
            set project_ids 1 ; # Special project_id to not display the project information
            set subproject_sql ""
        }
    }
    summary {
        set subproject_sql "and project_id in (	
            select p.project_id
            from im_projects p, im_projects parent_p
            where parent_p.project_id = :project_id
            and p.tree_sortkey between parent_p.tree_sortkey and tree_right(parent_p.tree_sortkey)
            and p.project_status_id not in (82)
        )"
        if {$filter_project_id eq ""} {
            set project_ids [db_list project_ids "select project_id from im_projects where parent_id is null and project_type_id not in (100,101) and project_id in ([template::util::tcl_to_sql_list [im_parent_projects -project_ids $project_ids]])"]
        } else {
            set project_ids [db_list project_ids "select project_id from im_projects where parent_id = :filter_project_id and project_type_id not in (100,101)"]
            if {$project_ids eq ""} {set project_ids $filter_project_id}
        }
    }
    detailed {
        # Only show hours logged on the project itself or the timesheet tasks below it
        set subproject_sql "and project_id in (	
            select p.project_id
            from im_projects p
            where parent_id = :project_id
            and p.project_status_id not in (82)
            and p.project_type_id in (100,101)
            UNION select :project_id from dual
        )"
    }
}


# Approved comes from the category type "Intranet Timesheet Conf Status"
if {$approved_only_p && [apm_package_installed_p "intranet-timesheet2-workflow"]} {
    set timescale_value_sql "select sum(hours) as sum_hours,$timescale_sql as timescale_header, user_id
                            from im_hours, im_timesheet_conf_objects tco
                            where tco.conf_id = im_hours.conf_object_id and tco.conf_status_id = 17010
                            $subproject_sql
                            and day >= :start_date
                            and day <= :end_date
                            group by user_id,timescale_header
                            order by user_id,timescale_header
                          "
} else {
    set timescale_value_sql "select sum(hours) as sum_hours,$timescale_sql as timescale_header,user_id
                             from im_hours
                             where day >= :start_date
                            and day <= :end_date
                            $subproject_sql
                            group by user_id,timescale_header
                            order by user_id,timescale_header
                          "
}


# If we want the percentages, we need to 
# Load the total hours a user has logged in case we are looking at the
# actuals or forecast

# Approved comes from the category type "Intranet Timesheet Conf Status"
if {$approved_only_p && [apm_package_installed_p "intranet-timesheet2-workflow"]} {
    set hours_sql "select sum(hours) as total, to_char(day,'YYMM') as month, user_id
	from im_hours, im_timesheet_conf_objects tco
        where tco.conf_id = im_hours.conf_object_id and tco.conf_status_id = 17010
	group by user_id, month"
} else {
    set hours_sql "select sum(hours) as total, to_char(day,'YYMM') as month, user_id
	from im_hours
	group by user_id, month"
}

if {"percentage" == $dimension} {
    db_foreach logged_hours $hours_sql {
        	if {$user_id != "" && $month != ""} {
	       set user_hours_${month}_${user_id} $total
	   }
    }
}

# Run through each combination of user and projec to retrieve the
# values

# Load the user - project - timescale into an array

# ---------------------------------------------------------------
# Overwrite the projects in case we have single or summary view.
# ---------------------------------------------------------------


foreach project_id $project_ids {
    db_foreach timescale_info $timescale_value_sql {
        set project_hours(${user_id}-$project_id) $sum_hours
        set var ${user_id}_${project_id}($timescale_header)
        if {"percentage" == $dimension} {
            if {[info exists user_hours_${timescale_header}_$user_id]} {
                set total [set user_hours_${timescale_header}_$user_id]
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
}

if {$with_absences_p == 1 && [lsearch $project_ids 1]<0} {
    lappend project_ids "0"; # Special project_id for absences! (only if we don't show single and all projects
}

# List for the hidden users
set displayed_user_ids [list]

foreach user_id $user_list {
    
    set user_name [im_name_from_user_id $user_id]

    if {$detail_level == "detailed"} {
        set project_ids [lsort -unique $user_projects($user_id)]
        if {$with_absences_p == 1} {
            lappend project_ids "0"; # Special project_id for absences! 
        }
    }

    if {$with_absences_p == 1} {
        # Get the list of absences for the user and create a new line for the user
        if {$approved_only_p} {
            set absence_dates [im_absence_dates -owner_id $user_id -start_date $start_date -end_date $end_date -absence_status_id 16000]
        } else {
            set absence_dates [im_absence_dates -owner_id $user_id -start_date $start_date -end_date $end_date -absence_status_id 16001]            
        }
        
        set values_list [list]
        foreach absence_date $absence_dates {
            lappend values_list "('$absence_date'::date,$hours_per_absence)"
        }
        if {[llength $values_list]>0} {
            # ---------------------------------------------------------------
            # Create a special project line for absences and calculate
            # the absence hours using a virtual table made up of the 
            # absence hours
            # ---------------------------------------------------------------

            set values_sql "(values [join $values_list ","]) as absences (day,hours)"
            set absence_timescale_value_sql "select sum(hours) as sum_hours,$timescale_sql as timescale_header
                  from $values_sql
                  group by timescale_header order by timescale_header"

            set project_id 0 ; # Special Project_id for the "absences" virtual project
            db_foreach absence_timescale_info $absence_timescale_value_sql {
                set project_hours(${user_id}-$project_id) 1
                set var ${user_id}_${project_id}($timescale_header)
                if {"percentage" == $dimension} {
                    if {[info exists user_hours_${timescale_header}_$user_id]} {
                        set total [set user_hours_${timescale_header}_$user_id]
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
        }
    }
    
    foreach project_id $project_ids {
        # Now load all the months variables
        # We need to differentiate by the view type to know where we get
        # the values from
        
        if {[info exists project_hours(${user_id}-$project_id)]} {
            lappend displayed_user_ids $user_id
            # ---------------------------------------------------------------
            # Now we append the actual row for the user_id and project_id
            # ---------------------------------------------------------------
            append __output "<table:table-row table:style-name=\"ro1\">\n"
            append table_body_html "<tr>"

            # Get the column information for the view
            # If we have a special project_id, don't query the projects table
            switch $project_id {
                0 {
                    set project_name "Absences"
                    db_1row project_info_query "
                                        select personnel_number,employee_id
                                        $view_arr(extra_selects_sql)
                                        from im_employees e
                                        $view_arr(extra_froms_sql)
                                        where e.employee_id = :user_id
                                        limit 1"
                    
                    set project_url [export_vars -base "/intranet-timesheet2/absences/index" -url {{user_id_from_search $user_id}}]
                }
                1 {
                    set project_name "All"
                    set project_url ""
                    db_1row project_info_query "
                    select personnel_number,employee_id
                    $view_arr(extra_selects_sql)
                    from im_employees e
                    $view_arr(extra_froms_sql)
                    where e.employee_id = :user_id
                    limit 1"
                }
                default {
                    db_1row project_info_query "
                        select project_name,personnel_number,p.project_id,employee_id,project_nr,company_id, project_type_id
                        $view_arr(extra_selects_sql)
                        from im_projects p, im_employees e
                        $view_arr(extra_froms_sql)
                        where e.employee_id = :user_id
                        and p.project_id = :project_id
                        limit 1
                    " 
                    set project_url [export_vars -base "/intranet/projects/view" -url {project_id}]
                }
                
            }
            foreach column_var $view_arr(column_vars) {
                set column_value [expr $column_var]
                # HTML
                append table_body_html "<td>$column_value</td>"
                # and XLS
                append __output " <table:table-cell office:value-type=\"string\"><text:p>$column_value</text:p></table:table-cell>\n"
            }

            # Now create the actual columns for the timescale
            foreach timescale_header $timescale_headers {
                set var ${user_id}_${project_id}($timescale_header)
                if {[info exists $var]} {
                    set value [set $var]
                } else {
                    set value ""
                }
                if {$project_id eq 1} {
                    # We need to add the absences to the value as this is the special case
                    # where we only display the user and not the projects, so all values
                    # are being aggregated.
                    set absence_var ${user_id}_0($timescale_header)
                    if {[info exists $absence_var]} {
                        set value [expr $value + [set $absence_var]]
                    }
                    append table_body_html "<td>${value}</td>"
                    append __output "<table:table-cell office:value-type=\"float\" office:value=\"$value\"></table:table-cell>"
                } else {
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

# ---------------------------------------------------------------
# Display the name of the users which are not included in the list
# ---------------------------------------------------------------

set hidden_users_html "<ul>"
set hidden_user_ids [list]

foreach user_id $user_list {
    if {[lsearch $displayed_user_ids $user_id]<0} {
        lappend hidden_user_ids $user_id
    }
}

if {[llength $hidden_user_ids]>0} {
    db_foreach hidden_users "select user_id,im_name_from_user_id(user_id, $name_order) as user_name from users where user_id in ([template::util::tcl_to_sql_list $hidden_user_ids]) order by user_name" {
        set hidden_user_url [export_vars -base "/intranet/users/view" -url {user_id}]
        append hidden_users_html "<li><a href='$hidden_user_url'>$user_name</li>"
    }
}