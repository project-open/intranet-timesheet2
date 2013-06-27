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
    @param duration	numbers of days shown on report. Default is 7
    @param start_at	start the report at this day
    @param display	if project_id, choose to display all hours or project hours
    @param workflow_key workflow_key to indicate if hours have been confirmed      

    @author mbryzek@arsdigita.com
    @author Frank Bergmann (frank.bergmann@project-open.com)
    @author Alwin Egger (alwin.egger@gmx.net)
} {
    { owner_id:integer "" }
    { project_id:integer "" }
    { cost_center_id:integer "" }
    { duration:integer "7" }
    { start_at:integer "" }
    { display "subproject" }
    { approved_only_p:integer "0"}
    { workflow_key ""}
}

# ---------------------------------------------------------------
# Defaults & Security
# ---------------------------------------------------------------

set extra_wheres [list]
set extra_froms [list]
set extra_left_joins [list]
set extra_selects [list]

set extra_order_by ""

set user_id [ad_maybe_redirect_for_registration]
set subsite_id [ad_conn subsite_id]
set site_url "/intranet-timesheet2"
set return_url "$site_url/weekly_report"
set date_format "YYYYMMDD"

if {![im_permission $user_id "view_hours_all"] && $owner_id == ""} {
    set owner_id $user_id
}

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

if { $start_at == "" } {
    set start_at [db_string get_today "select to_char(next_day(to_date(to_char(sysdate,:date_format),:date_format)+1, 'sun'), :date_format) from dual"]
    ad_returnredirect "$return_url?[export_url_vars start_at duration project_id owner_id]"
} else {
    set start_at [db_string get_today "select to_char(next_day(to_date(:start_at, :date_format), 'sun'), :date_format) from dual"]
}

if { $project_id != "" } {
    set error_msg [lang::message::lookup "" intranet-core.No_name_for_project_id "No Name for project %project_id%"]
    set project_name [db_string get_project_name "select project_name from im_projects where project_id = :project_id" -default $error_msg]
}


# ---------------------------------------------------------------
# Format the Filter and admin Links
# ---------------------------------------------------------------

set form_id "report_filter"
set action_url "/intranet-timesheet2/weekly_report"
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
        {project_id:text(select),optional {label \#intranet-cost.Project\#} {options $project_options} {value $project_id}}
    }

if {[apm_package_installed_p intranet-timesheet2-workflow]} {
    ad_form -extend -name $form_id -form {
	{approved_only_p:text(select),optional {label \#intranet-timesheet2.OnlyApprovedHours\# ?} {options {{[_ intranet-core.Yes] "1"} {[_ intranet-core.No] "0"}}} {value 0}}
    }
}

if { $project_id != "" && [im_permission $user_id "view_hours_all"]} {
    # As we allow Project Managers to view the timesheet, do not allow them to change the view to all 
    # users if they don't have the permission view_hours_all
    ad_form -extend -name $form_id -form {
	{display:text(select) {label "Level of Details"} {options $levels} {value $display}}
    }
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

## Deal with user filters
im_dynfield::append_attributes_to_form \
    -object_type "person" \
    -form_id $form_id \
    -page_url "/intranet-timesheet2/weekly-report" \
    -advanced_filter_p 1 \
    -object_id 0

# Set the form values from the HTTP form variable frame
im_dynfield::set_form_values_from_http -form_id $form_id

array set extra_sql_array [im_dynfield::search_sql_criteria_from_form \
			       -form_id $form_id \
			       -object_type "person"
			  ]



eval [template::adp_compile -string {<formtemplate id="$form_id" style="tiny-plain-po"></formtemplate>}]
set filter_html $__adp_output

# ---------------------------------------------------------------
# Get the Column Headers and prepare some SQL
# ---------------------------------------------------------------

set table_header_html "<tr><td class=rowtitle>[_ intranet-timesheet2.Users]</td>"
set days [list]
set holydays [list]
set sql_from [list]
set sql_from2 [list]

for { set i [expr $duration - 1]  } { $i >= 0 } { incr i -1 } {
	set col_sql "
    select 
	to_char(sysdate, :date_format) as today_date,
	to_char(to_date(:start_at, :date_format)-$i, :date_format) as i_date, 
	to_char((to_date(:start_at, :date_format)-$i), 'Day') as f_date_day,
	to_char((to_date(:start_at, :date_format)-$i), 'dd') as f_date_dd,
	to_char((to_date(:start_at, :date_format)-$i), 'MM') as f_date_mon,
	to_char((to_date(:start_at, :date_format)-$i), 'yyyy') as f_date_yyyy,    
	to_char(to_date(:start_at, :date_format)-$i, 'DY') as h_date 
    from dual"

    db_1row get_date $col_sql
    lappend days $i_date
    if { $h_date == "SAT" || $h_date == "SUN" } {
	lappend holydays $i_date
    }
    #prepare the data to UNION
    lappend sql_from "
    	select 
    		to_date('$i_date', :date_format) as day, 
    		owner_id, 
    		absence_id, 
    		'a' as type, 
    		im_category_from_id(absence_type_id) as descr 
    	from
    		im_user_absences
    	where
    		to_date('$i_date', :date_format) between 
    			trunc(to_date(to_char(start_date,:date_format),:date_format),'Day') and 
    			trunc(to_date(to_char(end_date,:date_format),:date_format),'Day')
    "
    lappend sql_from2 "select to_date('$i_date', :date_format) as day from dual\n"

    if { 1 == [stripzeros $f_date_mon] } {
	set f_date_mon_index 0
    } else {
	set f_date_mon_index [expr [stripzeros $f_date_mon]-1]	
    }

    set f_date "[_ intranet-timesheet2.[string trim $f_date_day]] <br> $f_date_dd. [lindex [_ acs-lang.localization-mon] $f_date_mon_index] <br>$f_date_yyyy" 
    append table_header_html "<td class=rowtitle>$f_date</td>"
}

append table_header_html "</tr>"

# ---------------------------------------------------------------
# Get the Data and fill it up into lists
# ---------------------------------------------------------------

if { $owner_id == "" && $project_id == "" } {
    set mode 1
    set sql_where ""  
} elseif { $owner_id == "" && $project_id != "" } {
    set mode 2
    set sql_where "and u.user_id in (select object_id_two from acs_rels where object_id_one=:project_id)"
} elseif { $owner_id != "" && $project_id == "" } {
    set mode 3
    set sql_where "and u.user_id = :owner_id"
} elseif { $owner_id != "" && $project_id != "" } {
    set mode 4
    set sql_where "and u.user_id in (select object_id_two from acs_rels where object_id_one=:project_id)  and u.user_id = :owner_id"
} else {
    ad_return_complaint "[_ intranet-timesheet2.Unexpected_Error]" "<li>[_ intranet-timesheet2._user_id]"
}

set sql_from_joined [join $sql_from " UNION "]
set sql_from2_joined [join $sql_from2 " UNION "]

# Approved comes from the category type "Intranet Timesheet Conf Status"
if {$approved_only_p} {
    set approved_from ", im_timesheet_conf_objects tco"
    set approved_where "and tco.conf_id = im_hours.conf_object_id and tco.conf_status_id = 17010"
} else {
    set approved_from ""
    set approved_where ""
}

if { $project_id != "" && $display ne "all"} {
    if {$display eq "project"} {
	set sql_from_imhours "select day, user_id, sum(hours) as val, 'h' as type, '' as descr from im_hours $approved_from where project_id = :project_id $approved_where group by user_id, day"
	append sql_from_im_hours "UNION select day, user_id, sum(hours) as val, 'h' as type, '' as desc from im_hours $approved_from where project_id in (select project_id from im_projects where project_type_id in (100,101) and parent_id = :project_id) $approved_where"
    } else {
	set sql_from_imhours "select day, user_id, sum(hours) as val, 'h' as type, '' as descr 
                              from im_hours $approved_from where project_id in (
                                select p.project_id
                                from im_projects p, im_projects parent_p
                                where parent_p.project_id = :project_id
                                and p.tree_sortkey between parent_p.tree_sortkey and tree_right(parent_p.tree_sortkey)
                                and p.project_status_id not in (82)) $approved_where group by user_id, day
"
    }
} else {
    set sql_from_imhours "select day, user_id, sum(hours) as val, 'h' as type, '' as descr from im_hours $approved_from where 1=1 $approved_where group by user_id, day"
}


# Select the list 
set active_users_sql "
-- Users who have the permission to add hours
select distinct party_id
from acs_object_party_privilege_map m
where m.object_id = :subsite_id
 and m.privilege = 'add_hours'
UNION
-- Users with the permissions to add absences
select distinct party_id
from acs_object_party_privilege_map m
where m.object_id = :subsite_id
and m.privilege = 'add_absences'
UNION
-- Users who have actually logged absences
select distinct owner_id as party_id
from im_user_absences
UNION
-- Users who have actually logged hours
select distinct user_id as party_id from im_hours  $approved_from where 1=1 $approved_where
"

if { "" != $cost_center_id } {
        lappend extra_wheres "
        u.user_id in (select employee_id from im_employees where department_id in (select object_id from acs_object_context_index where ancestor_id = $cost_center_id) or u.user_id = :user_id)
"
}

# Join the "extra_" SQL pieces 

set extra_from [join $extra_froms ",\n\t"]
set extra_left_join [join $extra_left_joins "\n\t"]
set extra_select [join $extra_selects ",\n\t"]
set extra_where [join $extra_wheres "\n\tand "]

if {"" != $extra_from} { set extra_from ",$extra_from" }
if {"" != $extra_select} { set extra_select ",$extra_select" }
if {"" != $extra_where} { set extra_where "and $extra_where" }

set switch_link_html "<a href=\"weekly_report?[export_url_vars owner_id project_id duration display cost_center_id]"


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
set dynfield_extra_where $extra_sql_array(where)
set ns_set_vars $extra_sql_array(bind_vars)
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

set name_order [parameter::get -package_id [apm_package_id_from_key intranet-core] -parameter "NameOrder" -default 1]

set sql "
select 
	u.user_id as curr_owner_id,
	im_name_from_user_id(u.user_id, $name_order) as owner_name,
	i.val,
	i.type,
	i.descr,
	to_char(d.day, :date_format) as curr_day
from
	cc_users u,
	($sql_from_imhours
	  UNION
	$sql_from_joined
	  UNION
	(select to_date(:start_at, :date_format), user_id, 0, '', '' from users)) i,
	($sql_from2_joined) d,
	($active_users_sql) active_users
where
	u.user_id > 0
	and u.member_state in ('approved')
	and u.user_id=i.user_id 
	and trunc(to_date(to_char(d.day,:date_format),:date_format),'Day')=trunc(to_date(to_char(i.day,:date_format),:date_format),'Day')
	and u.user_id = active_users.party_id
	$sql_where
	$extra_where
order by
	owner_name, curr_day
"

set old_owner [list]
set table_body_html ""
set bgcolor(0) " class=roweven "
set bgcolor(1) " class=rowodd "
set ctr 0

ns_log notice  $sql



db_foreach get_hours $sql {

    # This loop handles absence and hour records, to be distinguished by field '$type'
    # Example: 
    # 
    #    35327 | Peter GUDENBURG         | 66944 | a    | Vacation | 20120525
    #    35327 | Peter GUDENBURG         |     0 |      |          | 20120527
    #    35609 | Peter GERLAND           |  8.00 | h    |          | 20120521
    #    35609 | Peter GERLAND           |  8.00 | h    |          | 20120522
    #    35609 | Peter GERLAND           |  8.00 | h    |          | 20120523
    #    35609 | Peter GERLAND           |  8.00 | h    |          | 20120524
    #    35609 | Peter GERLAND           |  8.00 | h    |          | 20120525
    #    35609 | Peter GERLAND           |     0 |      |          | 20120527

    # Only when absence and hour arrays are set for user, the line will be written 

    ns_log notice  "weekly_report: Next in loop: owner name: $owner_name ($curr_owner_id)"

    # Skip first record for first loop 
    if { $ctr == 0 } { set old_owner [list $curr_owner_id $owner_name]}

    ns_log notice  "weekly_report: Checking: Do we write row? Old owner: [lindex $old_owner 1] ([lindex $old_owner 0]), current owner: $owner_name ($curr_owner_id)"
   
    if { [lindex $old_owner 0] != $curr_owner_id } {
	ns_log notice  "weekly_report: loop: Writing row user: [lindex $old_owner 1] ([lindex $old_owner 0])"	
	append table_body_html [im_do_row \
				    [array get bgcolor] \
				    $ctr \
				    [lindex $old_owner 0] \
				    [lindex $old_owner 1] \
				    $days \
				    [array get user_days] \
				    [array get user_absences] \
				    $holydays \
				    $today_date \
				    [array get user_ab_descr] \
				    $workflow_key \
			       ]
	set old_owner [list $curr_owner_id $owner_name]
	array unset user_days
	array unset user_absences
    }

    # Set hours 
    if { $type == "h" } {
	set user_days($curr_day) $val
    }
    
    # Set absences 
    if { $type == "a" } {
	set user_absences($curr_day) $val
	set user_ab_descr($val) $descr
    }
    set val ""
    incr ctr
}

set colspan [expr [llength $days]+1]

if { $ctr > 0 } {
    # Writing last record 
    ns_log notice  "weekly_report: left loop, now writing last record" 
    append table_body_html [im_do_row [array get bgcolor] $ctr $curr_owner_id $owner_name $days [array get user_days] [array get user_absences] $holydays $today_date [array get user_ab_descr] $workflow_key ]
} elseif { [empty_string_p $table_body_html] } {
    # Show a reasonable message when there are no result rows:
    set table_body_html "
	 <tr><td colspan=$colspan><ul><li><b>
	[_ intranet-timesheet2.No_Users_found]
	</b></ul></td></tr>"
}

# ---------------------------------------------------------------
# Provide << and >> to see future and past days
# ---------------------------------------------------------------

set navig_sql "
    select 
    	to_char(to_date(:start_at, :date_format) - $duration, :date_format) as past_date,
	to_char(to_date(:start_at, :date_format) + $duration, :date_format) as future_date 
    from 
    	dual"
db_1row get_navig_dates $navig_sql

set switch_past_html "$switch_link_html&start_at=$past_date&workflow_key=$workflow_key\">&laquo;</a>"
set switch_future_html "$switch_link_html&start_at=$future_date&workflow_key=$workflow_key\">&raquo;"

# ---------------------------------------------------------------
# Format Table Continuation and title
# ---------------------------------------------------------------

set table_continuation_html "
<tr>
  <td align='left'>
     <span class='backward_smaller_than'>$switch_past_html</span>
  </td>
  <td colspan=[expr $colspan - 2]></td>
  <td align='right'>
    <span class='forward_greater_than'>$switch_future_html</span>
  </td>
</tr>\n"

set page_title "[_ intranet-timesheet2.Timesheet_Summary]"
set context_bar [im_context_bar $page_title]
if { $owner_id != "" && [info exists owner_name] } {
    append page_title " of $owner_name"
}
if { $project_id != "" && [info exists project_name] } {
    append page_title " by project \"$project_name\""
}


# ---------------------------------------------------------------
# 
# ---------------------------------------------------------------


set left_navbar_html "
            <div class=\"filter-block\">
                $filter_html
            </div>
"

