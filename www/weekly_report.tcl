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

proc stripzeros {value} {
    set retval [string trimleft $value 0]
    if { ![string length $retval] } { return 0 } 
    return $retval
}

ad_proc wf_status_list  {
    { user_id }
    { days  }
    { workflow_key }
} {
    Returns list of lists of format {[ansi-date] [wf-status]}
    Example: {20120720 2} {20120719 2} {20120721 1}
} {

    set first_day_of_week [clock format [clock scan [lindex $days 0]] -format {%Y-%m-%d}]
    set last_day_of_week [clock format [clock scan [lindex $days 6]] -format {%Y-%m-%d}]

    set sql "
        select
                to_char(h.day,'YYYYMMDD') as day,
                wf.state,
                h.hours
        from
                im_hours h,
                wf_cases wf
        where
                h.day <= :last_day_of_week and
                h.day >= :first_day_of_week and
                wf.workflow_key = :workflow_key and
                wf.object_id = h.conf_object_id and
                h.user_id = :user_id
        
	UNION

	select
                to_char(h.day,'YYYYMMDD') as day,
                '' as state,
                h.hours
        from
                im_hours h
        where
                h.day <= :last_day_of_week and
                h.day >= :first_day_of_week and
                h.user_id = :user_id and 
		h.conf_object_id is null
	order by
		day

    "
   
    db_foreach col $sql {
	set wf_hour_status_list [list]
	if { ![info exists logged_array($day)] } {
		set logged_array($day) [lappend wf_hour_status_list $hours $state]
	} else {
		# There's a value for this day, always overwrite if state = "finish"
		if { "finished" == [lindex $logged_array($day) 1] } {
	 		set logged_array($day) [lappend wf_hour_status_list $hours $state]
		}	
	}
    }    

    set wf_status_list [list]

    foreach list_day $days {
	if { [info exists logged_array($list_day)] } {
		set return_array($list_day) 0
		if { "" == [lindex $logged_array($list_day) 1] } {
			# No WF for this day 
			set return_array($list_day) 0 	
			ns_log NOTICE "weekly_report-wf_status_list: NO WF found for user: $user_id for day: $list_day"
		} else {
			# We have a WF case for this day  
			if { "finished" == [lindex $logged_array($list_day) 1] } {
				set return_array($list_day) 2	
    				ns_log NOTICE "weekly_report-wf_status_list: FINISHED WF found for user: $user_id for day: $list_day"
			} else {
				# WF is active			
				set return_array($list_day) 1
    				ns_log NOTICE "weekly_report-wf_status_list: ACTIVE WF found for user: $user_id for day: $list_day"
			}
		}
	}
    }

    foreach i [array names return_array] {
	lappend wf_status_list "$i $return_array($i)" 
    }
    ns_log NOTICE "weekly_report-wf_status_list: WF Status List for user $user_id: $wf_status_list"
    return $wf_status_list
}

ad_proc im_do_row {
    { bgcolorl }
    { ctr }
    { curr_owner_id }
    { owner_name }
    { days }
    { user_daysl }
    { absencel }
    { holydays }
    { today_date }
    { descrl }
    { workflow_key }
} {
    Returns a row with the hours loged of one user
    'days' is a list of dates in format 'YYYYMMDD' with seven elements, first day 

} {

    set user_view_page "/intranet/users/view"
    set absence_view_page "/intranet-timesheet2/absences/new?form_mode=display"
    set date_format "YYYY-MM-DD"

    array set bgcolor $bgcolorl
    array set user_days $user_daysl
    array set absence $absencel
    array set descr $descrl
    array set absence_arr {}
    set html ""

    # get 'new' absence array
    set first_day_absence_arr [clock format [clock scan [lindex $days 0]] -format {%Y-%m-%d}]
    set last_day_absence_arr [clock format [clock scan [lindex $days 6]] -format {%Y-%m-%d} ]
    set sql "select * from im_absences_get_absences_for_user(:curr_owner_id, :first_day_absence_arr::date, :last_day_absence_arr::date, null) AS (absence_date date, absence_type_id int, absence_id int)"

    db_foreach absence_arr $sql {
        # Find index of $days
        set day_idx [lsearch -exact $days [clock format [clock scan $absence_date] -format {%Y%m%d}] ]
        if { "-1" == $day_idx } {
            ns_log NOTICE "weekly_report: ERROR: day index not found in list 'days'"
            continue
        }
        # Set array
        if { [info exists absence_arr($day_idx)] } {
            append absence_arr($day_idx) "<br><a href=\"$absence_view_page&absence_id=$absence_id\" style=\"color:\\\\\\#FF0000;\">[_ intranet-timesheet2.Absent]</a> ([im_category_from_id $absence_type_id])"
        } else {
            set absence_arr($day_idx) "<a href=\"$absence_view_page&absence_id=$absence_id\" style=\"color:\\\\\\\#FF0000;\">[_ intranet-timesheet2.Absent]</a> ([im_category_from_id $absence_type_id])"
        }
    }
    ns_log NOTICE "weekly_report: New Absence Array for user_id: $curr_owner_id ($first_day_absence_arr/$last_day_absence_arr) [array get absence_arr]"

    # Write HEADER 
    append html "
    	<tr$bgcolor([expr $ctr % 2])>
    	    <td>
    	        <a href=\"$user_view_page?user_id=$curr_owner_id\">$owner_name</a>
    	    </td>
    "

    # Adding feature: Set background of cell indicating WF status 
    if { "" != $workflow_key } {
	set wf_status_list [wf_status_list $curr_owner_id $days $workflow_key]
	# wf_status_list list of lists {ansi-date status} 
	# Example: {20120720 2} {20120719 2} {20120721 1}
	ns_log NOTICE "KHD: wf_status_list: $wf_status_list"

	foreach rec $wf_status_list {
	    set wf_status_array([lindex [split $rec " "] 0]) [lindex [split $rec " "] 1]
	    ns_log NOTICE "weekly_report - WF status list - wf_status_array([lindex [split $rec " "] 0]) [lindex [split $rec " "] 1]"
    	}
    }

    for { set i 0 } { $i < [llength $days] } { incr i } {
	# Defaults 
	set cell_text [list]
	set cell_param [list]
	set absent_p "f"

        # Write absences
        if { [info exists absence_arr($i)] } {
            lappend cell_text $absence_arr($i)
            set absent_p "t"
        }

	# Check for hours logged and write hours logged for this day (if applicable) 
	if { [info exists user_days([lindex $days $i])] } {
	    set label_hours_weekly_report [lang::message::lookup "" intranet-timesheet2.hours_weekly_report "h"]
	    lappend cell_text "$user_days([lindex $days $i]) $label_hours_weekly_report"
	    set absent_p "t"	
	    if { "" != $workflow_key } {
		switch $wf_status_array([lindex $days $i]) {
		    "1" {
			# WF in progress - blue
			set cell_param "style='background-color:\#99ffff;'"
		    }
		    "2" {
			# Finished WF - green
			set cell_param "style='background-color:\#99CC33;'"			
		    }
		    default {
		    }
		}
	   }
	} 
	
	# If no hours are logged and no absences are registered, set bg color of cell to yellow 
        if { $absent_p == "f" } {
             lappend cell_text "[_ intranet-timesheet2.No_hours_logged]"
             lappend cell_param "style=\"background-color: #ffcc66;\""
        }

        # Color code weekends?
        set color_code_we_p [parameter::get -package_id [apm_package_id_from_key intranet-timesheet2] -parameter "WeeklyReportColorCodeWeekendsP" -default 1]
        if { [lsearch -exact $holydays [lindex $days $i]] >= 0 && !$color_code_we_p } {
            set cell_param "style=\"background-color: \#DDDDDD;\""
        }
	append html "<td [join $cell_param " "]>[join $cell_text "<br>"]</td>\n"
    }
    append html "</tr>\n"
    return $html
}


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
    { project_id:integer 0 }
    { duration:integer "7" }
    { start_at:integer "" }
    { display "project" }
    { cost_center_id:integer 0 }
    { department_id:integer 0 }
    { workflow_key ""}
}

# ---------------------------------------------------------------
# Defaults & Security
# ---------------------------------------------------------------

set user_id [ad_maybe_redirect_for_registration]
set subsite_id [ad_conn subsite_id]
set site_url "/intranet-timesheet2"
set return_url "$site_url/weekly_report"
set date_format "YYYYMMDD"
 
if { $owner_id != $user_id && ![im_permission $user_id "view_hours_all"] } {
    ad_return_complaint 1 "<li>[_ intranet-timesheet2.lt_You_have_no_rights_to]"
    return

}

if { $start_at == "" && $project_id != 0 } {

    set hours_start_date [db_string get_new_start_at "
	select	to_char(max(day), :date_format) 
	from	im_hours 
	where	project_id = :project_id
    " -default ""]

    set project_start_date [db_string get_project_start "
	select	to_char(start_date, :date_format) 
	from	im_projects
	where	project_id = :project_id
    " -default ""]

    set todays_date [db_string todays_date "
	select	to_char(now(), :date_format) 
	from	dual
    " -default ""]

    set start_at $hours_start_date
    if {"" == $start_at} { 
	set start_at $project_start_date 
    }
    if {"" == $start_at} { 
	set start_at $todays_date 
    }
    if {"" == $start_at} {
	ad_return_complaint 1 "Unable to determine start date for project \#$project_id:<br>
        please set the 'Start Date' of the project"
	return
    }

    ad_returnredirect "$return_url?[export_url_vars start_at duration project_id owner_id workflow_key]"
    return
}


if { $start_at == "" } {
    set start_at [db_string get_today "select to_char(next_day(to_date(to_char(sysdate,:date_format),:date_format)+1, 'sun'), :date_format) from dual"]
} else {
    set start_at [db_string get_today "select to_char(next_day(to_date(:start_at, :date_format), 'sun'), :date_format) from dual"]
}

if { $project_id != 0 } {
    set error_msg [lang::message::lookup "" intranet-core.No_name_for_project_id "No Name for project %project_id%"]
    set project_name [db_string get_project_name "select project_name from im_projects where project_id = :project_id" -default $error_msg]
}


# ---------------------------------------------------------------
# Format the Filter and admin Links
# ---------------------------------------------------------------

set sel_all ""
set sel_pro ""

if { $display == "all" } { set sel_all "selected" }
if { $display == "project" } { set sel_pro "selected" }

if { $project_id != 0 } {
    set filter_form_html "
	<form method=get action='$return_url' name=filter_form>
	[export_vars -form {start_at duration project_id owner_id workflow_key}]
	<table border=0 cellpadding=0 cellspacing=0>
	<tr>
	  <td colspan='2' class=rowtitle align=center>
	[_ intranet-timesheet2.Filter]
	  </td>
	</tr>
	<tr>
	  <td valign=top>[_ intranet-timesheet2.Display] </td>
	<td valign=top><select name=display size=1>
	<option value=\"project\" $sel_pro>[_ intranet-timesheet2.lt_hours_spend_on_projec]</option>
	<option value=\"all\" $sel_all>[_ intranet-timesheet2.hours_spend_overall]</option>
	</select></td>
	</tr>
	  <td></td>
	  <td valign=top>
	    <input type=submit value='[_ intranet-timesheet2.Apply]' name=submit>
	  </td>
	</tr>
	</table>
	<!-- <a href=\"$return_url?\">[_ intranet-timesheet2.lt_Display_all_hours_on_]</a> -->
	</form>"
} else {

        # ad_return_complaint 1 $workflow_key

	set include_empty 1
	set department_only_p 1
	set im_department_select [im_cost_center_select -include_empty $include_empty  -department_only_p $department_only_p  department_id $department_id [im_cost_type_timesheet]]

        set include_empty 1
        set department_only_p 
        set im_cc_select [im_cost_center_select -include_empty $include_empty  -department_only_p $department_only_p  cost_center_id $cost_center_id [im_cost_type_timesheet]]

	set filter_form_html "
	<form method=post action='$return_url' name=filter_form>
	[export_vars -form {start_at duration project_id owner_id workflow_key}]	
	<div class='filter-block'>
		<div class='filter-title'>[_ intranet-timesheet2.Filter]</div>
		<table border=0 cellpadding=5 cellspacing=5>
		<tr>
	        <td valign=top><strong>[_ intranet-core.Cost_Center]:</strong><br>$im_cc_select </td>
	        </tr>
                <tr>
                <td valign=top>&nbsp;</td>
                </tr>
        	<tr>
	        <td valign=top><strong>[_ intranet-core.Department]:</strong><br>$im_department_select</td>
	        </tr>
	        <tr>
	          <td valign=top colspan='2'>
		        <input type=submit value='[_ intranet-timesheet2.Apply]' name=submit>
	          </td>
        	</tr>
		</table>
	</div>
	</form>	
"
}

if { [im_permission $user_id "add_absences"] } {
    append admin_html "<li><a href=/intranet-timesheet2/absences/new>[_ intranet-timesheet2.Add_a_new_Absence]</a></li>\n"
}
if { [im_permission $user_id "view_absences_all"] } {
    append admin_html "<li><a href=/intranet-timesheet2/absences>[_ intranet-timesheet2.View_all_Absences]</a></li>\n"
}
if { [im_permission $user_id "add_hours"] } {
    append admin_html "<li><a href=/intranet-timesheet2/hours>[_ intranet-timesheet2.Log_your_hours]</a></li>\n"
}


# 2010-12-10: Links should no more appear on this report, moved to /intranet-timesheet2/absences/index 
# 
# if { $admin_html != "" } {
#     set filter_html [append filter_form_html "<ul>$admin_html</ul>"]
# } else {
    set filter_html $filter_form_html
# }

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

if { $owner_id == "" && $project_id == 0 } {
    set mode 1
    set sql_where ""  
} elseif { $owner_id == "" && $project_id != 0 } {
    set mode 2
    set sql_where "and u.user_id in (select object_id_two from acs_rels where object_id_one=:project_id)"
} elseif { $owner_id != "" && $project_id == 0 } {
    set mode 3
    set sql_where "and u.user_id = :owner_id"
} elseif { $owner_id != "" && $project_id != 0 } {
    set mode 4
    set sql_where "and u.user_id in (select object_id_two from acs_rels where object_id_one=:project_id)  and u.user_id = :owner_id"
} else {
    ad_return_complaint "[_ intranet-timesheet2.Unexpected_Error]" "<li>[_ intranet-timesheet2._user_id]"
}

set sql_from_joined [join $sql_from " UNION "]
set sql_from2_joined [join $sql_from2 " UNION "]

if { $project_id != 0 && $display == "project"} {
    set sql_from_imhours "select day, user_id, sum(hours) as val, 'h' as type, '' as descr from im_hours where project_id = :project_id group by user_id, day"
} else {
    set sql_from_imhours "select day, user_id, sum(hours) as val, 'h' as type, '' as descr from im_hours group by user_id, day"
}


# Select the list 
set active_users_sql "
-- Users who have the permission to add hours
select distinct
	party_id
from	acs_object_party_privilege_map m
where	m.object_id = :subsite_id
	and m.privilege = 'add_hours'
UNION
-- Users with the permissions to add absences
select distinct
	party_id
from	acs_object_party_privilege_map m
where	m.object_id = :subsite_id
	and m.privilege = 'add_absences'
UNION
-- Users who have actually logged absences
select distinct
	owner_id as party_id
from	im_user_absences
"

set cc_filter_where ""
if { "0" != $cost_center_id &&  "" != $cost_center_id } {
        set cc_filter_where "
        and u.user_id in (select employee_id from im_employees where department_id in (select object_id from acs_object_context_index where ancestor_id = $cost_center_id))
"
}

set department_filter_where ""
set cost_center_code [db_string get_cc_code "select cost_center_code from im_cost_centers where cost_center_id = :department_id" -default ""]

if { "0" != $department_id &&  "" != $department_id } {
	set department_filter_where "
	   and 
		u.user_id in (
			select employee_id from im_employees where department_id in (
				select 
					object_id 
				from 
					acs_object_context_index 
				where 
					ancestor_id = $department_id  
		) 
	   )
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
	$department_filter_where
	$cc_filter_where
order by
	owner_name, curr_day
"

set old_owner [list]
set table_body_html ""
set bgcolor(0) " class=roweven "
set bgcolor(1) " class=rowodd "
set ctr 0

ns_log NOTICE $sql



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

    ns_log NOTICE "weekly_report: Next in loop: owner name: $owner_name ($curr_owner_id)"

    # Skip first record for first loop 
    if { $ctr == 0 } { set old_owner [list $curr_owner_id $owner_name]}

    ns_log NOTICE "weekly_report: Checking: Do we write row? Old owner: [lindex $old_owner 1] ([lindex $old_owner 0]), current owner: $owner_name ($curr_owner_id)"
   
    if { [lindex $old_owner 0] != $curr_owner_id } {
	ns_log NOTICE "weekly_report: loop: Writing row user: [lindex $old_owner 1] ([lindex $old_owner 0])"	
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
    ns_log NOTICE "weekly_report: left loop, now writing last record" 
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
    	to_char(to_date(:start_at, :date_format) - 7, :date_format) as past_date,
	to_char(to_date(:start_at, :date_format) + 7, :date_format) as future_date 
    from 
    	dual"
db_1row get_navig_dates $navig_sql

set switch_link_html "<a href=\"weekly_report?[export_url_vars owner_id project_id duration display]"

set switch_past_html "$switch_link_html&start_at=$past_date&cost_center_id=$cost_center_id&department_id=$department_id&workflow_key=$workflow_key\">&laquo;</a>"
set switch_future_html "$switch_link_html&start_at=$future_date&cost_center_id=$cost_center_id&department_id=$department_id&workflow_key=$workflow_key\">&raquo;"

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
if { $project_id != 0 && [info exists project_name] } {
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

