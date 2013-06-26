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
    { view_type "" }
    { dimension "" }
}

# ---------------------------------------------------------------
# Defaults & Security
# ---------------------------------------------------------------

set extra_order_by ""

set user_id [ad_maybe_redirect_for_registration]
set admin_p [im_is_user_site_wide_or_intranet_admin $user_id]
set subsite_id [ad_conn subsite_id]
set site_url "/intranet-timesheet2"
set return_url "$site_url/hours_report"
set date_format "YYYY-MM-DD"

# We need to set the overall hours per month an employee is working
# Make this a default for all for now.
set hours_per_month [expr [parameter::get -parameter TimesheetWorkDaysPerYear] * [parameter::get -parameter TimesheetHoursPerDay] / 12] 

if {"" == $start_date} { 
    set start_date [db_string get_today "select to_char(sysdate,'YYYY-01-01
') from dual"]   
}

if {"" == $end_date} { 
    # if no end_date is given, set it to six months in the future
    set end_date [db_string current_month "select to_char(sysdate + interval '6 month',:date_format) from dual"]
}


# Get the first and last month
set start_month [db_string start_month "select to_char(to_date(:start_date,'YYYY-MM-DD'),'YYMM') from dual"]
set end_month [db_string end_month "select to_char(to_date(:end_date,'YYYY-MM-DD'),'YYMM') from dual"]


if {"" == $view_type} { set view_type "actual" }
if {"" == $dimension} { set dimension "hours" }

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
# 3. Defined Table Fields
# ---------------------------------------------------------------

# Define the column headers and column contents that 
# we want to show:
#

im_view_set_def_vars -view_name $view_name -array_name "view_arr"


# ---------------------------------------------------------------
# Format the Filter and admin Links
# ---------------------------------------------------------------

set form_id "report_filter"
set action_url "/intranet-timesheet2/hours_report"
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
    {dimension:text(select) {label "Dimension"} {options {{Hours hours} {Percentage percentage}}}}
    {view_type:text(select) {label "Type"} {options {{Planning planning} {Actual actual} {Forecast forecast}}}}
    {start_date:text(text) {label "[_ intranet-timesheet2.Start_Date]"} {value "$start_date"} {html {size 10}} {after_html {<input type="button" style="height:20px; width:20px; background: url('/resources/acs-templating/calendar.gif');" onclick ="return showCalendar('start_date', 'y-m-d');" >}}}
    {end_date:text(text) {label "[_ intranet-timesheet2.End_Date]"} {value "$end_date"} {html {size 10}} {after_html {<input type="button" style="height:20px; width:20px; background: url('/resources/acs-templating/calendar.gif');" onclick ="return showCalendar('end_date', 'y-m-d');" >}}}
    {view_name:text(select) {label \#intranet-core.View_Name\#} {value "$view_name"} {options $view_options}}
}

eval [template::adp_compile -string {<formtemplate id="$form_id" style="tiny-plain-po"></formtemplate>}]
set filter_html $__adp_output

# ---------------------------------------------------------------
# Get the Column Headers and prepare some SQL
# ---------------------------------------------------------------

set table_header_html "<tr><td class=rowtitle>[_ intranet-timesheet2.Users]</td><td class=rowtitle>[_ intranet-core.Project]</td>"

# Format the header names with links that modify the
# sort order of the SQL query.
#
set url "index?"
set query_string [export_ns_set_vars url [list order_by]]
if { ![empty_string_p $query_string] } {
    append url "$query_string&"
}

set ctr 0
foreach col $view_arr(column_headers) {
    set wrench_html [lindex $view_arr(column_headers_admin) $ctr]
    regsub -all " " $col "_" col_txt
    set col_txt [lang::message::lookup "" intranet-core.$col_txt $col]
    if {$ctr == 0} {
	append table_header_html "<td class=rowtitle>$col_txt$wrench_html</td>\n"
    } else {
	#set col [lang::util::suggest_key $col]
	append table_header_html "<td class=rowtitle><a href=\"${url}order_by=[ns_urlencode $col]\">$col_txt</a>$wrench_html</td>\n"
    }
    incr ctr
}

# Prepare the months headers
set current_month $start_month
while {$current_month<=$end_month} {
    lappend column_headers $current_month
    set current_month [db_string current_month "select to_char(to_date(:current_month,'YYMM') + interval '1 month','YYMM') from dual"]
}

foreach col $column_headers {
    # Append the months to the header
    append table_header_html "<td class=rowtitle>$col</td>\n"
}

# ---------------------------------------------------------------
# Get the Data and fill it up into lists
# ---------------------------------------------------------------

# Filter by owner_id
if {$owner_id != ""} {
    lappend view_arr(extra_where) "u.user_id = :owner_id"
}    

# Approved comes from the category type "Intranet Timesheet Conf Status"
if {$approved_only_p} {
    lappend view_arr(extra_from) "im_timesheet_conf_objects tco"
    lappend view_arr(extra_where) "tco.conf_id = im_hours.conf_object_id and tco.conf_status_id = 17010"
}

# Filter for projects
if {$project_id != ""} {
    # Get all hours for this project, including hours logged on
    # tasks (100) or tickets (101)
    lappend view_arr(extra_where) "project_id in (select project_id from im_projects where project_type_id in (100,101) and parent_id = :project_id union :project_id)"
}

# Filter for department_id
if { "" != $cost_center_id } {
        lappend view_arr(extra_where) "
        u.user_id in (select employee_id from im_employees where department_id in (select object_id from acs_object_context_index where ancestor_id = $cost_center_id) or u.user_id = :user_id)
"
}

# Join the "extra_" SQL pieces 

set extra_from [join $view_arr(extra_from) ",\n\t"]
if { ![empty_string_p $extra_from] } {set extra_from ",$extra_from"}

set extra_select [join $view_arr(extra_select) ",\n\t"]
if { ![empty_string_p $extra_select] } {set extra_from ",$extra_select"}

set extra_where [join $view_arr(extra_where) "\n\tand "]
if { ![empty_string_p $extra_where] } {set extra_from " and $extra_where"}

# Create a ns_set with all local variables in order
# to pass it to the SQL query
set form_vars [ns_set create]
foreach varname [info locals] {

    # Don't consider variables that start with a "_", that
    # contain a ":" or that are array variables:
    if {"_" == [string range $varname 0 0]} { continue }
    if {[regexp {:} $varname]} { continue }
    if {[array exists $varname]} { continue }

    # Get the value of the variable and add to the form_vars set
    set value [expr "\$$varname"]
    ns_set put $form_vars $varname $value
}

# Add the DynField variables to $form_vars
set dynfield_extra_where ""
set ns_set_vars ""
set tmp_vars [util_list_to_ns_set $ns_set_vars]
set tmp_var_size [ns_set size $tmp_vars]
for {set i 0} {$i < $tmp_var_size} { incr i } {
    set key [ns_set key $tmp_vars $i]
    set value [ns_set get $tmp_vars $key]
    set $key $value
    set switch_link_html "$switch_link_html&[export_url_vars $key]"
    ns_set put $form_vars $key $value
}


# Add the additional condition to the "where_clause"
if {"" != $dynfield_extra_where} { 
    append extra_where "
                and u.user_id in $dynfield_extra_where
            "
}

set table_body_html ""


# Get the username / project combinations
set user_projects [list]
db_foreach projects_info_query "
    select username,project_name,personnel_number,project_id,employee_id,project_nr,company_id
    from im_planning_items i, im_projects p, im_employees e, users u
    where u.user_id = i.item_project_member_id
    and p.project_id = i.item_project_phase_id
    and e.employee_id = u.user_id
    group by username,project_name,personnel_number,employee_id,project_id,project_nr,company_id
    order by username,project_name
" {
    set user_project "${employee_id}-${project_id}"
    lappend user_projects $user_project
    append table_body($user_project) "<td>$username</td><td>$project_name</td>"
    # append dynamic values
    append table_body($user_project) "<td>$project_id</td>"
   
}

# Now go for the extra data

# If we want the percentages, we need to 
# Load the total hours a user has logged in case we are looking at the
# actuals or forecast

if {"percentage" == $dimension && "planned" != $view_type} {
    db_foreach logged_hours {select sum(hours) as total, to_char(day,'YYMM') as month, user_id
	from im_hours
	group by user_id, month
    } {
	if {$user_id != "" && $month != ""} {
	    set user_hours_${month}_${user_id} $total
	}
    }
}

foreach user_project $user_projects {
    set ttt [split $user_project "-"]
    set employee_id [lindex $ttt 0]
    set project_id [lindex $ttt 1]
    
    # Try to avoid building an array
    # Loop through all the column headers and set them to ""
    foreach month $column_headers {
	set $month ""
	set planned($month) "0"
    }
    
    # Now load all the months variables
    # We need to differentiate by the view type to know where we get
    # the values from
    switch $view_type {
	actual {
	    # get the hours only
	    db_foreach months_info {select sum(hours) as sum_hours, to_char(day,'YYMM') as month
		from im_hours
		where user_id = :employee_id
		and project_id = :project_id
		group by month
	    } {
		if {"percentage" == $dimension} {
		    set total [set user_hours_${month}_$employee_id]
		    if {0 < $total} {
			set $month "[expr round($sum_hours / $total *100)]%"
		    } 
		} else {
		    set $month $sum_hours
		}
	    }
	}
	forecast {
	    set current_month [db_string current_month "select to_char(now(),'YYMM') from dual"]
	    # First get the forecasted hours including the current month
	    if {"percentage" == $dimension} {
		set sql {
		    select round(item_value,0) || '%' as value, to_char(item_date,'YYMM') as month 
		    from im_planning_items 
		    where item_project_member_id = :employee_id
		    and item_project_phase_id = :project_id
		}
	    } else {
		# As we deal with actual hours, we need to use the
		# hours_per_month do translate the percentage based planning
		set sql {
		    select round(item_value/100 * :hours_per_month,0) as value, to_char(item_date,'YYMM') as month 
		    from im_planning_items 
		    where item_project_member_id = :employee_id
		    and item_project_phase_id = :project_id
		}
	    }
	    db_foreach months_info $sql {
		set planned($month) $value
	    }
	    
	    # Now get the actual hours until the current month
	    # get the hours only
	    set start_of_month "${current_month}01"
	    db_foreach months_info {select sum(hours) as sum_hours, to_char(day,'YYMM') as month
		from im_hours
		where user_id = :employee_id
		and project_id = :project_id
		and day < to_date(:start_of_month,'YYMMDD')
		group by month
	    } {
		if {"percentage" == $dimension} {
		    set total [set user_hours_${month}_$employee_id]
		    if {0 < $total} {
			set $month "[expr round($sum_hours / $total *100)]%"
		    } else {
			set $month ""
		    }
		} else {
		    set $month $sum_hours
		}
		
		# if the actual differs form planned, highlight this
		# by appending the planned value
		if {![info exists planned(${month})]} {
		    set planned($month) 0
		}
		if {"percentage" == $dimension && $planned($month) == 0} {
		    append planned($month) "%"
		}
		if {[set $month] != $planned($month)} {
		    set $month "[set $month] ($planned($month))"
		}
	    }
	    
	} 
	planning {
	    db_foreach months_info {		    
		select round(item_value,0) || '%' as value, to_char(item_date,'YYMM') as month 
		from im_planning_items 
		where item_project_member_id = :employee_id
		and item_project_phase_id = :project_id
	    } {
		set $month $value
	    }
	}
    }

    # Now append the values
    foreach month $column_headers {
	if {[set $month] == "" && $planned($month) != 0} {
	    set value "($planned($month))"
	} else {
	    set value [set $month]
	}
	append table_months($user_project) "<td>$value</td>"
    }

    append csv_line "\r\n"
    append csv_body $csv_line
    incr ctr
}



# Now loop again through the user_projects so we can build up the
# table_html

foreach user_project $user_projects {
    # Get the non value columns
    append table_body_html "<tr>
      $table_body($user_project)
      $table_months($user_project)
      </tr>
    "
}   
 
set sql "
select 
        h.*,
        u.*
from
        im_hours h, users u
where
	u.user_id > 0
	and u.member_state in ('approved')
	and u.user_id=h.user_id 
"
ds_comment "SQL to display: $sql"


set left_navbar_html "
            <div class=\"filter-block\">
                $filter_html
            </div>
"