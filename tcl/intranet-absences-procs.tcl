# /packages/intranet-timesheet2/tcl/intranet-absences-procs.tcl
#
# Copyright (C) 1998-2009 various parties
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

ad_library {
    Definitions for the intranet timesheet

    @author unknown@arsdigita.com
    @author frank.bergmann@project-open.com
}

# ---------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------

ad_proc -public im_user_absence_type_vacation {} { return 5000 }
ad_proc -public im_user_absence_type_personal {} { return 5001 }
ad_proc -public im_user_absence_type_sick {} { return 5002 }
ad_proc -public im_user_absence_type_travel {} { return 5003 }
ad_proc -public im_user_absence_type_training {} { return 5004 }
ad_proc -public im_user_absence_type_bank_holiday {} { return 5005 }


ad_proc -public im_user_absence_status_active {} { return 16000 }
ad_proc -public im_user_absence_status_deleted {} { return 16002 }
ad_proc -public im_user_absence_status_requested {} { return 16004 }
ad_proc -public im_user_absence_status_rejected {} { return 16006 }



# ---------------------------------------------------------------------
# Absences Permissions
# ---------------------------------------------------------------------

ad_proc -public im_user_absence_permissions {user_id absence_id view_var read_var write_var admin_var} {
    Fill the "by-reference" variables read, write and admin
    with the permissions of $user_id on $absence_id
} {
    upvar $view_var view
    upvar $read_var read
    upvar $write_var write
    upvar $admin_var admin
    
    set view 1
    set read 1
    set write 1
    set admin 1
    
    # No read - no write...
    if {!$read} {
        set write 0
        set admin 0
    }
}


ad_proc absence_list_for_user_and_time_period {user_id first_julian_date last_julian_date} {
    For a given user and time period, this proc returns a list 
    of elements where each element corresponds to one day and describes its
    "work/vacation type".
} {
    # Select all vacation periods that have at least one day
    # in the given time period.
    set sql "
	-- Direct absences owner_id = user_id
	select
                to_char(start_date,'yyyy-mm-dd') as start_date,
                to_char(end_date,'yyyy-mm-dd') as end_date,
		im_category_from_id(absence_type_id) as absence_type,
		im_category_from_id(absence_status_id) as absence_status,
		absence_id
	from
		im_user_absences
	where
		owner_id = :user_id and
		group_id is null and
		start_date <= to_date(:last_julian_date,'J') and
		end_date   >= to_date(:first_julian_date,'J')
    UNION
	-- Absences via groups - Check if the user is a member of group_id
	select
		to_char(start_date,'yyyy-mm-dd') as start_date,
		to_char(end_date,'yyyy-mm-dd') as end_date,
		im_category_from_id(absence_type_id) as absence_type,
		im_category_from_id(absence_status_id) as absence_status,
		absence_id
	from 
		im_user_absences
	where 
		group_id in (
                        select
                                group_id
                        from
                                group_element_index gei,
                                membership_rels mr
                        where
                                gei.rel_id = mr.rel_id and
                                mr.member_state = 'approved' and
                                gei.element_id = :user_id
		) and
		start_date <= to_date(:last_julian_date,'J') and
		end_date   >= to_date(:first_julian_date,'J')
    "


    # Initialize array with "" elements.
    for {set i $first_julian_date} {$i<=$last_julian_date} {incr i} {
	set vacation($i) ""
    }

    # Process vacation periods and modify array accordingly.
    db_foreach vacation_period $sql {
    
	set absence_status_3letter [string range $absence_status 0 2]
        set absence_status_3letter_l10n [lang::message::lookup "" intranet-timesheet2.Absence_status_3letter_$absence_status_3letter $absence_status_3letter]
	set absent_status_3letter_l10n $absence_status_3letter_l10n

	regsub " " $absence_type "_" absence_type_key
	set absence_type_l10n [lang::message::lookup "" intranet-core.$absence_type_key $absence_type]

	set start_date_julian [db_string get_data "select to_char('$start_date'::date,'J')" -default 0]
	set end_date_julian [db_string get_data "select to_char('$end_date'::date,'J')" -default 0]

	for {set i [max $start_date_julian $first_julian_date]} {$i<=[min $end_date_julian $last_julian_date]} {incr i } {
	   set vacation($i) "
		<a href=\"/intranet-timesheet2/absences/new?form_mode=display&absence_id=$absence_id\"
		>[_ intranet-timesheet2.Absent_1]</a> 
		$absence_type_l10n<br>
           "
	}
    }
    # Return the relevant part of the array as a list.
    set result [list]
    for {set i $first_julian_date} {$i<=$last_julian_date} {incr i} {
	lappend result $vacation($i)
    }
    return $result
}


ad_proc im_timesheet_absences_sum { 
    -user_id:required
    {-number_days 7} 
} {
    Returns the total number of absences multiplied by 8 hours per absence.
} {
    set hours_per_absence [parameter::get -package_id [im_package_timesheet2_id] -parameter "TimesheetHoursPerAbsence" -default 8]

    set num_absences [db_string absences_sum "
		select	count(*)
		from
			im_user_absences a,
			im_day_enumerator(now()::date - '$number_days'::integer, now()::date) d
		where
			owner_id = :user_id
			and a.start_date <= d.d
			and a.end_date >= d.d
    " -default 0]
    if {"" == $num_absences} { set num_absences 0}
    return [expr $num_absences * $hours_per_absence]
}


ad_proc -public im_get_next_absence_link { { user_id } } {
    Returns a html link with the next "personal"absence of the given user_id.
    Do not show Bank Holidays.
} {
    set sql "
	select	absence_id,
		to_char(start_date,'yyyy-mm-dd') as start_date,
		to_char(end_date, 'yyyy-mm-dd') as end_date
	from
		im_user_absences, dual
	where
		owner_id = :user_id and
		group_id is null and
		start_date >= now()
	order by
		start_date, end_date
    "

    set ret_val ""
    db_foreach select_next_absence $sql {
	set ret_val "<a href=\"/intranet-timesheet2/absences/new?form_mode=display&absence_id=$absence_id\">$start_date - $end_date</a>"
	break
    }
    return $ret_val
}


# ---------------------------------------------------------------------
# Absence Workflow Permissions
#
# You can replace these functions with custom functions by modifying parameters.
# ---------------------------------------------------------------------


ad_proc im_absence_new_page_wf_perm_table { } {
    Returns a hash array representing (role x status) -> (v r d w a),
    controlling the read and write permissions on absences,
    depending on the users's role and the WF status.
} {
    set req [im_user_absence_status_requested]
    set rej [im_user_absence_status_rejected]
    set act [im_user_absence_status_active]
    set del [im_user_absence_status_deleted]

    set perm_hash(owner-$rej) {v r}
    set perm_hash(owner-$req) {v r d w}
    set perm_hash(owner-$act) {v r d}
    set perm_hash(owner-$del) {v r}

    set perm_hash(assignee-$rej) {v r w}
    set perm_hash(assignee-$req) {v r w}
    set perm_hash(assignee-$act) {v r}
    set perm_hash(assignee-$del) {v r}

    set perm_hash(hr-$rej) {v r d w a}
    set perm_hash(hr-$req) {v r d w a}
    set perm_hash(hr-$act) {v r d w a}
    set perm_hash(hr-$del) {v r d w a}

    return [array get perm_hash]
}


ad_proc im_absence_new_page_wf_perm_edit_button {
    -absence_id:required
} {
    Should we show the "Edit" button in the AbsenceNewPage?
    The button is visible only for the Owner of the absence
    and the Admin, but nobody else during the course of the WF.
    Also, the Absence should not be changed anymore once it has
    started.
} {
    set perm_table [im_absence_new_page_wf_perm_table]
    set perm_set [im_workflow_object_permissions \
		    -object_id $absence_id \
		    -perm_table $perm_table
    ]

    ns_log Debug "im_absence_new_page_wf_perm_edit_button absence_id=$absence_id => $perm_set"
    return [expr [lsearch $perm_set "w"] > -1]
}

ad_proc im_absence_new_page_wf_perm_delete_button {
    -absence_id:required
} {
    Should we show the "Delete" button in the AbsenceNewPage?
    The button is visible only for the Owner of the absence,
    but nobody else in the WF.
} {
    set perm_table [im_absence_new_page_wf_perm_table]
    set perm_set [im_workflow_object_permissions \
		    -object_id $absence_id \
		    -perm_table $perm_table
    ]

#    ad_return_complaint 1 $perm_table



    ns_log Debug "im_absence_new_page_wf_perm_delete_button absence_id=$absence_id => $perm_set"
    return [expr [lsearch $perm_set "d"] > -1]
}


# ---------------------------------------------------------------------
# Absence Cube
# ---------------------------------------------------------------------

ad_proc im_absence_cube_color_list { } {
    Returns the list of colors for the various types of absences
} {
    # ad_return_complaint 1 [util_memoize im_absence_cube_color_list_helper]
    return [util_memoize im_absence_cube_color_list_helper]
}

ad_proc im_absence_cube_color_list_helper { } {
    Returns the list of colors for the various types of absences
} {


    # define default color set 
    set color_list {
        EC9559
        E2849B
        53A7D8
        A185CB
        FFF956
        006666
        FFCC99
        CCCCC9
        CCCCC9
        CCCCC9
        CCCCC9
        CCCCC9
        CCCCC9
        CCCCC9
        CCCCC9
        CCCCC9
        CCCCC9
        CCCCC9
        CCCCC9
        CCCCC9
    }

    # Overwrite in case there's a custom color defined 
    set col_sql "
        select  category_id, category, enabled_p, aux_string2
        from    im_categories
        where
                category_type = 'Intranet Absence Type'
        order by category_id
     "

    set ctr 0 
    db_foreach cols $col_sql {
	if { "" == $aux_string2 } {
	    lset color_list $ctr [lindex $color_list $ctr]
	} else {
	    lset color_list $ctr $aux_string2
	}
	incr ctr
    }
    return $color_list

}


ad_proc im_absence_mix_colors {
    value
} {
    Renders a single report cell, depending on value.
    Value consists of a string of 0..5 representing the last digit
    of the absence_type:
            5000 | Vacation	- Red
            5001 | Personal	- Orange
            5002 | Sick		- Blue
            5003 | Travel	- Purple
            5004 | Training	- Yellow
            5005 | Bank Holiday	- Grey
    " " indentifies an "empty vacation", which is represented with
    color white. This is necessary to represent weekly absences,
    where less then 5 days are taken as absence.
    Value contains a string of last digits of the absence types.
    Multiple values are possible for example "05", meaning that
    a Vacation and a holiday meet. 
} {
    # Show empty cells according to even/odd row formatting
    if {"" == $value} { return "" }
    set value [string toupper $value]

    # Define a list of colours to pick from
    set color_list [im_absence_cube_color_list]

    set hex_list {0 1 2 3 4 5 6 7 8 9 A B C D E F}

    set len [string length $value]
    set r 0
    set g 0
    set b 0
    
    # Mix the colors for each of the characters in "value"
    for {set i 0} {$i < $len} {incr i} {
	set v [string range $value $i $i]

	set col "FFFFFF"
	if {" " != $v} { set col [lindex $color_list $v] }

	set r [expr $r + [lsearch $hex_list [string range $col 0 0]] * 16]
	set r [expr $r + [lsearch $hex_list [string range $col 1 1]]]
	
	set g [expr $g + [lsearch $hex_list [string range $col 2 2]] * 16]
	set g [expr $g + [lsearch $hex_list [string range $col 3 3]]]
	
	set b [expr $b + [lsearch $hex_list [string range $col 4 4]] * 16]
	set b [expr $b + [lsearch $hex_list [string range $col 5 5]]]
    }
    
    # Calculate the median
    set r [expr $r / $len]
    set g [expr $g / $len]
    set b [expr $b / $len]

    # Convert the RGB values back into a hex color string
    set color ""
    append color [lindex $hex_list [expr $r / 16]]
    append color [lindex $hex_list [expr $r % 16]]
    append color [lindex $hex_list [expr $g / 16]]
    append color [lindex $hex_list [expr $g % 16]]
    append color [lindex $hex_list [expr $b / 16]]
    append color [lindex $hex_list [expr $b % 16]]

    return $color
}



ad_proc im_absence_cube_render_cell {
    value
} {
    Renders a single report cell, depending on value.
    Takes the color from absences color lookup.
} {
    set color [im_absence_mix_colors $value]
    if {"" != $color} {
	return "<td bgcolor=\#$color>&nbsp;</td>\n"
    } else {
	return "<td>&nbsp;</td>\n"
    }
}

ad_proc im_absence_cube {
    {-num_days 21}
    {-absence_status_id "" }
    {-absence_type_id "" }
    {-user_selection "" }
    {-timescale "" }
    {-report_start_date "" }
    {-report_end_date "" }
    {-user_id_from_search "" }
    {-user_id ""}
    {-cost_center_id ""}
    {-hide_colors_p 0}
    {-project_id ""}
} {
    Returns a rendered cube with a graphical absence display
    for users.
} {
    switch $timescale {
	today { 
	    return ""
	    ad_script_abort
	}
	all { 
            return [lang::message::lookup "" intranet-timesheet2.AbsenceCubeNotShownAllAbsences "Graphical view of absences not available for Timescale option 'All'. Please choose a different option."]
            ad_script_abort
	}
	custom {
	    if {[catch {
		set num_days [db_string get_number_days "select (:report_end_date::date - :report_start_date::date);" -default 0]
		incr num_days
	    } err_msg]} {
		set num_days 93
	    }
	}
	next_3w { set num_days 21 }
	last_3w { set num_days 21 }
	next_1m { set num_days 31 }
	past { 
            return [lang::message::lookup "" intranet-timesheet2.AbsenceCubeNotShownPastAbsences "Graphical view of absences not available for Timescale option 'Past'. Please choose a different option."]
            ad_script_abort
	}
	future { set num_days 93 }
	last_3m { set num_days 93 }
	next_3m { set num_days 93 }
	default {
	    set num_days 31
	}
    }

    if { $num_days > 370 } {
	return [lang::message::lookup "" intranet-timesheet2.AbsenceCubeNotShownGreateOneYear "Graphical view of absences only available for periods less than 1 year"]
	ad_script_abort 
    }


    set user_url "/intranet/users/view"
    set date_format "YYYY-MM-DD"
    set current_user_id [ad_get_user_id]
    set bgcolor(0) " class=roweven "
    set bgcolor(1) " class=rowodd "
    set name_order [parameter::get -package_id [apm_package_id_from_key intranet-core] -parameter "NameOrder" -default 1]

    if {"" == $report_start_date || "2000-01-01" == $report_start_date} {
	set report_start_date [db_string start_date "select now()::date"]
    }

    if { "" == $report_end_date } {
	set report_end_date [db_string end_date "select :report_start_date::date + :num_days::integer"]	
    }

    if {-1 == $absence_type_id} { set absence_type_id "" }

    # ---------------------------------------------------------------
    # Limit the number of users and days
    # ---------------------------------------------------------------

    set criteria [list]
    if {"" != $absence_type_id && 0 != $absence_type_id} {
	lappend criteria "a.absence_type_id = '$absence_type_id'"
    }
    if {"" != $absence_status_id && 0 != $absence_status_id} {
	lappend criteria "a.absence_status_id = '$absence_status_id'"
    }

    switch $user_selection {
	"all" {
	    # Nothing.
	}
	"mine" {
	    lappend criteria "u.user_id = :current_user_id"
	}
	"employees" {
	    lappend criteria "a.owner_id in (select employee_id from im_employees)"
	}
	"providers" {
	    lappend criteria "u.user_id IN (select	m.member_id 
							from	group_approved_member_map m 
							where	m.group_id = [im_freelance_group_id]
							)"
	}
	"customers" {
	    lappend criteria "u.user_id IN (select	m.member_id
                                                        from	group_approved_member_map m
                                                        where	m.group_id = [im_customer_group_id]
                                                        )"
	}
	"direct_reports" {
	    lappend criteria "a.owner_id in (select employee_id from im_employees where supervisor_id = :current_user_id and employee_status_id = '454')"
	}  
	"cost_center" {
	    set cost_center_list [im_cost_center_options -parent_id $cost_center_id]
	    set cost_center_ids [list $cost_center_id]
            foreach cost_center $cost_center_list {
		lappend cost_center_ids [lindex $cost_center 1]
            }
	    lappend criteria "a.owner_id in (select employee_id from im_employees where department_id in ([template::util::tcl_to_sql_list $cost_center_ids]) and employee_status_id = '454')"
	}
	"project" {
	    set project_ids [im_project_subproject_ids -project_id $project_id]
	    lappend criteria "a.owner_id in (select object_id_two from acs_rels where object_id_one in ([template::util::tcl_to_sql_list $project_ids]))"
	}
	"user" {
	    lappend criteria "a.owner_id=:user_id"
	}	    
	default  {
	    # We shouldn't even be here, so just display his/her own ones
	    lappend criteria "a.owner_id = :current_user_id"
	}
    }
    set where_clause [join $criteria " and\n            "]
    if {![empty_string_p $where_clause]} {
	set where_clause " and $where_clause"
    }

    # ---------------------------------------------------------------
    # Determine Top Dimension
    # ---------------------------------------------------------------
    
    # Initialize the hash for holidays.
    array set holiday_hash {}
    set day_list [list]
    
    for {set i 0} {$i < $num_days} {incr i} {
	db_1row date_info "
	    select 
		to_char(:report_start_date::date + :i::integer, :date_format) as date_date,
		to_char(:report_start_date::date + :i::integer, 'Day') as date_day,
		to_char(:report_start_date::date + :i::integer, 'dd') as date_day_of_month,
		to_char(:report_start_date::date + :i::integer, 'Mon') as date_month,
		to_char(:report_start_date::date + :i::integer, 'YYYY') as date_year,
		to_char(:report_start_date::date + :i::integer, 'Dy') as date_weekday
        "

	set date_month [lang::message::lookup "" intranet-timesheet2.$date_month $date_month]

	if {$date_weekday == "Sat" || $date_weekday == "Sun"} { set holiday_hash($date_date) 5 }
	lappend day_list [list $date_date $date_day_of_month $date_month $date_year]
    }

    # ---------------------------------------------------------------
    # Determine Left Dimension
    # ---------------------------------------------------------------
    
    set user_list [db_list_of_lists user_list "
	select	u.user_id as user_id,
		im_name_from_user_id(u.user_id, $name_order) as user_name
	from	users u,
		cc_users cc
	where	u.user_id in (
			-- Individual Absences per user
			select	a.owner_id
			from	im_user_absences a,
				users u
			where	a.owner_id = u.user_id and
				a.start_date <= :report_end_date::date and
				a.end_date >= :report_start_date::date
				$where_clause
		     UNION
			-- Absences for user groups
			select	mm.member_id as owner_id
			from	im_user_absences a,
				users u,
				group_distinct_member_map mm
			where	mm.member_id = u.user_id and
				a.start_date <= :report_end_date::date and
				a.end_date >= :report_start_date::date and
				mm.group_id = a.group_id
				$where_clause
		)
		and cc.member_state = 'approved'
		and cc.user_id = u.user_id
	order by
		lower(im_name_from_user_id(u.user_id, $name_order))
    "]


    # Get list of categeory_ids to determine index 
    # needed for color codes

    set sql "
        select  category_id
        from    im_categories
        where   category_type = 'Intranet Absence Type'
        order by category_id
     "

    set category_list [list]
    db_foreach category_id $sql {
	lappend category_list [list $category_id]
    }

    # ---------------------------------------------------------------
    # Get individual absences
    # ---------------------------------------------------------------
    
    array set absence_hash {}
    set absence_sql "
	-- Individual Absences per user
	select	a.absence_type_id,
		a.owner_id,
		d.d
	from	im_user_absences a,
		users u,
		(select im_day_enumerator as d from im_day_enumerator(:report_start_date, :report_end_date)) d,
		cc_users cc
	where	a.owner_id = u.user_id and
		cc.user_id = u.user_id and 
		cc.member_state = 'approved' and
		a.start_date <= :report_end_date::date and
		a.end_date >= :report_start_date::date and
                date_trunc('day',d.d) between date_trunc('day',a.start_date) and date_trunc('day',a.end_date) 
		$where_clause
     UNION
	-- Absences for user groups
	select	a.absence_type_id,
		mm.member_id as owner_id,
		d.d
	from	im_user_absences a,
		users u,
		group_distinct_member_map mm,
		(select im_day_enumerator as d from im_day_enumerator(:report_start_date, :report_end_date)) d
	where	mm.member_id = u.user_id and
		a.start_date <= :report_end_date::date and
		a.end_date >= :report_start_date::date and
                date_trunc('day',d.d) between date_trunc('day',a.start_date) and date_trunc('day',a.end_date) and 
		mm.group_id = a.group_id
		$where_clause
    "

    # ToDo: re-factor so that color codes also work in case of more than 10 absence types
    db_foreach absences $absence_sql {
	set key "$owner_id-$d"
	set value ""
	if {[info exists absence_hash($key)]} { set value $absence_hash($key) }
	set absence_hash($key) [append value [lsearch $category_list $absence_type_id]]
    }

    # ---------------------------------------------------------------
    # Render the table
    # ---------------------------------------------------------------
    
    set table_header "<tr class=rowtitle>\n"
    append table_header "<td class=rowtitle>[_ intranet-core.User]</td>\n"
    foreach day $day_list {
	set date_date [lindex $day 0]
	set date_day_of_month [lindex $day 1]
	set date_month_of_year [lindex $day 2]
	set date_year [lindex $day 3]
	append table_header "<td class=rowtitle>$date_month_of_year<br>$date_day_of_month</td>\n"
    }
    
    append table_header "</tr>\n"
    set row_ctr 0
    set table_body ""
    foreach user_tuple $user_list {
	append table_body "<tr $bgcolor([expr $row_ctr % 2])>\n"
	set user_id [lindex $user_tuple 0]
	set user_name [lindex $user_tuple 1]
	append table_body "<td><nobr><a href='[export_vars -base $user_url {user_id}]'>$user_name</a></td></nobr>\n"
	foreach day $day_list {
	    set date_date [lindex $day 0]
	    set key "$user_id-$date_date"
	    set value ""
	    if {[info exists absence_hash($key)]} { set value $absence_hash($key) }
	    if {[info exists holiday_hash($date_date)]} { append value $holiday_hash($date_date) }
	    if {$hide_colors_p && $value != "" } {set value "1"}
	    append table_body [im_absence_cube_render_cell $value]
	    ns_log debug "intranet-absences-procs::im_absence_cube_render_cell: $value"
	}
	append table_body "</tr>\n"
	incr row_ctr
    }

    return "
	<table>
	$table_header
	$table_body
	</table>
    "
}

ad_proc -public im_absence_vacation_balance_component {
    -user_id_from_search:required
} {
    Returns a HTML component showing the number of days left
    for the user
} {

    # Show only if user is an employee
    if { ![im_user_is_employee_p $user_id_from_search] } { return "" }

    set current_user_id [ad_get_user_id]
    # This is a sensitive field, so only allows this for the user himself
    # and for users with HR permissions.

    set read_p 0
    if {$user_id_from_search == $current_user_id} { set read_p 1 }
    if {[im_permission $current_user_id view_hr]} { set read_p 1 }
    if {!$read_p} { return "" }

    set params [list \
		    [list user_id_from_search $user_id_from_search] \
		    [list return_url [im_url_with_query]] \
    ]

    set result [ad_parse_template -params $params "/packages/intranet-timesheet2/www/absences/vacation-balance-component"]
    return [string trim $result]
}


ad_proc -public im_absence_vacation_balance_component_xhtml {
    -user_id_from_search:required
} {
    Returns a HTML component for vacation management. 
    Allows viewing vacations for current, last and next year 
} {

    # Show only if user is an employee
    if { ![im_user_is_employee_p $user_id_from_search] } { return "" }

    set current_user_id [ad_get_user_id]
    # This is a sensitive field, so only allows this for the user himself
    # and for users with HR permissions.

    set read_p 0
    if {$user_id_from_search == $current_user_id} { set read_p 1 }
    if {[im_permission $current_user_id view_hr]} { set read_p 1 }
    if {!$read_p} { return "" }

    set result "
	[lang::message::lookup "" intranet-timesheet2.ShowVacationsFor "Show vacations for:"] &nbsp;
	<select id='im_absence_vacation_balance_component_select_vacation_period'>
	    <option value='this_year' selected> [lang::message::lookup "" intranet-timesheet2.ThisYear "This year"]</option>
	    <option value='last_year'> [lang::message::lookup "" intranet-timesheet2.LastYear "Last year"]</option>
	    <option value='next_year'> [lang::message::lookup "" intranet-timesheet2.NextYear "Next year"]</option>
	</select>
        <div id='im_absence_vacation_balance_component_container'>
		<br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
		<img src=\"/intranet/images/ajax-loader.gif\" alt=\"ajaxloader\">
		</div>
        <script type='text/JavaScript'>
                \$(function(){
                        // XHTML request
                        function getVacationPortlet() {
                                var LoadMsg = '<img src=\"/intranet/images/ajax-loader.gif\" alt=\"ajaxloader\">';
                                var _Href = '/intranet-timesheet2/absences/xhtml-vacation-balance-component';
                                var _VacPeriod = \$('#im_absence_vacation_balance_component_select_vacation_period').find('option:selected').val();
                                \$('<div id=\"loading\">'+LoadMsg+'</div>').appendTo('body').fadeIn('slow',function(){
                                        \$.ajax({
                                                type:           'GET',
                                                url:            _Href,
                                                data:           \"user_id_from_search=$user_id_from_search&period=\" + _VacPeriod,
                                                dataType:       'html',
                                                timeout:        5000,
                                                success: function(d,s){
                                                        \$('#loading').fadeOut('slow',function(){
                                                                \$(this).remove();
                                                                \$('#im_absence_vacation_balance_component_container').slideUp('slow',function(){
                                                                                \$(this).html(d).slideDown('slow');
                                                                        });
                                                                  });
                                                 },
                                                 error: function(o,s,e){
                                                     \$(\"\#im_absence_vacation_balance_component_container\").html('<br><span style=\"color:red\">An error has been occurred making this request:<br>' + e + '</span>');
                                                 }
                                        });
                                });
	                };

                        \$(\"#im_absence_vacation_balance_component_select_vacation_period\").change(function() {
                                getVacationPortlet();
                        });
                        // initial call
                        getVacationPortlet();
			
                });
        </script>
    "
    return [string trim $result]
}


ad_proc -public im_get_next_absence_link { { user_id } } {
    Returns a html link with the next "personal"absence of the given user_id.
    Do not show Bank Holidays.
} {
    set sql "
	select	absence_id,
		to_char(start_date,'yyyy-mm-dd') as start_date,
		to_char(end_date, 'yyyy-mm-dd') as end_date
	from
		im_user_absences, dual
	where
		owner_id = :user_id and
		group_id is null and
		start_date >= sysdate
	order by
		start_date, end_date
    "

    set ret_val ""
    db_foreach select_next_absence $sql {
	set ret_val "<a href=\"/intranet-timesheet2/absences/new?form_mode=display&absence_id=$absence_id\">$start_date - $end_date</a>"
	break
    }
    return $ret_val
}

ad_proc -public im_absence_user_component {
    -user_id:required
} {
    Returns a HTML component showing the vacations
    for the user
} {
    set current_user_id [ad_get_user_id]
    # This is a sensitive field, so only allows this for the user himself
    # and for users with HR permissions.

    set read_p 0
    if {$user_id == $current_user_id} { set read_p 1 }
    if {[im_permission $current_user_id view_hr]} { set read_p 1 }
    if {!$read_p} { return "" }

    set params [list \
		    [list user_id_from_search $user_id] \
		    [list return_url [im_url_with_query]] \
    ]

    set result [ad_parse_template -params $params "/packages/intranet-timesheet2/lib/user-absences"]
    return [string trim $result]
}

ad_proc -public im_absence_remaining_days {
    -user_id:required
    -absence_type_id:required
    -approved:boolean
    {-ignore_absence_ids ""}
} {
    Returns the number of remaining days for the user of a certain absence type
    @param ignore_absence_id Ignore this absence_id when calculating the remaining days.
} {
    if {[im_table_exists im_user_leave_entitlements]} {
	    return [im_leave_entitlement_remaining_days -user_id $user_id -absence_type_id $absence_type_id -approved_p $approved_p -ignore_absence_ids $ignore_absence_ids]
        ad_script_abort
    }
    
    set current_year [db_string current_year "select to_char(now(), 'YYYY')"]

    set start_of_year "$current_year-01-01"
    set end_of_year "$current_year-12-31"

    if {!$approved_p} {
        set approved_sql ""
    } else {
        set approved_sql ""
    }

    db_1row user_info "select coalesce(vacation_balance,0) as vacation_balance,
                          coalesce(vacation_days_per_year,0) as vacation_days_per_year,
                          coalesce(overtime_balance,0) as overtime_balance,
                          coalesce(rwh_days_last_year,0) as rwh_days_last_year,
                          coalesce(rwh_days_per_year,0) as rwh_days_per_year
                      from im_employees where employee_id = :user_id"
    switch $absence_type_id {
	5000 {
            # Vacation
	    set entitlement_days [expr $vacation_balance + $vacation_days_per_year]
	}
	5006 {
            # Overtime
            set entitlement_days $overtime_balance
        }
	5007 {
            # RTT
	    set entitlement_days [expr $rwh_days_last_year + $rwh_days_per_year]
	}
	default {
            set entitlement_days 0
	}
    }
    
    set absence_days [im_absence_days -owner_id $user_id -absence_type_ids $absence_type_id -start_date $start_of_year -end_date $end_of_year -approved_p $approved_p -ignore_absence_ids $ignore_absence_ids]
    set remaining_days [expr $entitlement_days - $absence_days]
    return $remaining_days
}

ad_proc -public im_absence_days {
    {-owner_id ""}
    {-group_ids ""}
    -absence_type_ids:required
    {-approved_p "0"}
    {-start_date ""}
    {-end_date ""}
    {-ignore_absence_ids ""}
} {
    Returns the number of absence days for the user or group of a certain absence type
    @param ignore_absence_id Ignore this absence_id when calculating the remaining days.
} {

    return [im_absence_dates -owner_id $owner_id -group_ids $group_ids -start_date $start_date -end_date $end_date -absence_type_ids $absence_type_ids -ignore_absence_ids $ignore_absence_ids -type "sum"]
}


#### Procedure to calculate the vacation days in a given time period, judged from the start and end dates

ad_proc -public im_absence_week_days {
    -start_date:required
    -end_date:required
    {-week_day_list {0 6}}
    {-type "dates"}
} {
    Given a list of week_days, return the actual dates for those week_days
    
    @param start_date Start of the interval
    @param end_date End of the interval
    @param week_day_list List of weekdays, where 0 = Sunday and 6 = Saturday. Defaults to the weekend (Saturday and Sunday, 6 & 0)
} {
    # Now substract the off days
    set week_day_clause_list [list]
    foreach week_day $week_day_list {
        lappend week_day_clause_list "extract('dow' FROM i)=$week_day" 
    }
    
    if {$week_day_list eq ""} { set where_clause ""} else { set where_clause "WHERE [join $week_day_clause_list " or "]"}

        set dates [db_list date_range "
            SELECT to_char(i,'YYYY-MM-DD')
            FROM (
              SELECT generate_series(start, finish, '1 day') AS i
              FROM
                  (VALUES(
                  '$start_date'::date,
                  '$end_date'::date
              )) AS t(\"start\", \"finish\")
            ) AS j
            $where_clause
        "]
    if {$type == "dates"} {
        return [lsort $dates]
    } else {
        return [llength $dates]
    }
    
    ns_log Notice "DATES $dates"
}

#### Procedure to calculate the days to take given a start and end date
ad_proc -public im_absence_dates {
    {-owner_id ""}
    {-group_ids ""}
    {-start_date ""}
    {-end_date ""}
    {-exclude_week_days {0 6}}
    {-absence_type_ids ""}
    {-absence_status_id ""}
    {-ignore_absence_ids ""}
    {-type "dates"}
} {
    Returns a list of dates in an interval, where an owner or a group is not working.
    
    @param owner_id Owner for whom we calculate the actual absence
    @param group_ids Alternatively calculate for this group_ids. If neither group_ids nor owner_id is provided return absences for any group
    @param start_date Start of the absence
    @param end_date End of the absence
    @param off_days Days which we do not count in our calculation. That is usually Saturday and Sunday (weekends), but might be other dates as well
    @param include_personal Should we include personal vacations in the calculation? Usually we don't, as they are e.g. sickness
    @param ignore_absence_id Ignore this absence_id when calculating the dates. This is helpful if we edit an existing absence and want to get the other days the user is off
    @param type "dates" which is default returns the dates. "sum" returns the actual amount of days and "absence_ids" lists the absences which fall in this timeframe
} {
    # Assume a long timescale for start/enddate
    if {$start_date eq ""} {
        set start_date "1970-01-01"
    }
    if {$end_date eq ""} {
	    set end_date "2099-12-31"
    }

    # If we have an owner_id limit the absences to only this owner and the group the owner belongs to
    
    if {$owner_id ne ""} {
        # Get the groups the owner belongs to
        set group_ids [db_list group_options "
            select	g.group_id
            from	groups g,
		            acs_objects o,
                    acs_rels r
            where	g.group_id = o.object_id and
                    o.object_type in ('im_profile', 'im_biz_object_group') and
                    r.object_id_one = g.group_id and
                    r.object_id_two = :owner_id
            order by g.group_name
         "]

         # Add registered_users
         lappend group_ids "-2"

         set owner_sql "and (owner_id = :owner_id or group_id in ([template::util::tcl_to_sql_list $group_ids]))"
    } elseif {$group_ids ne ""} {
        # We try to find the holidays for the group of users
        set owner_sql "and group_id in ([template::util::tcl_to_sql_list $group_ids])"
    } else {
        # We try to find the holidays for any group
        set owner_sql "and group_id is not null"
    }
    

    # We need to ignore this absence_id from the calculation of
    # absence days. Usually during an edit
    if {$ignore_absence_ids eq ""} {
	    set ignore_absence_sql ""
    } else {
        set ignore_absence_sql "and absence_id not in ([template::util::tcl_to_sql_list $ignore_absence_ids])"
    }
    
    # Check for the absence types
    if {""==$absence_type_ids} {
        set absence_type_sql ""
    } else {
        set absence_type_sql "and absence_type_id in ([template::util::tcl_to_sql_list $absence_type_ids])"
    }
    
    if {"" == $absence_status_id} {
        set absence_status_sql "absence_status_id != [im_user_absence_status_deleted]"
    } else {
        set absence_status_sql "absence_status_id = $absence_status_id"
    } 

    set absence_days [list]
    set absence_ids [list]

    #   Define the days of the week we look into
    set days_of_week [list 0 1 2 3 4 5 6]
    
    if {$exclude_week_days ne ""} {
        foreach exclude_day $exclude_week_days {
            set days_of_week  [lsearch -inline -all -not -exact $days_of_week $exclude_day]
        }
    }    

    # Now we need to find the absences which already exist in this timeframe and extract the dates it is occurring 
    db_foreach absence_ids "select absence_id, to_char(start_date,'YYYY-MM-DD') as absence_start_date, to_char(end_date,'YYYY-MM-DD') as absence_end_date
                from    im_user_absences 
                where   start_date <= to_date(:end_date,'YYYY-MM-DD') and
                        end_date >= to_date(:start_date,'YYYY-MM-DD') and
                        $absence_status_sql
                        $absence_type_sql
                        $owner_sql
                        $ignore_absence_sql 
                        " {
        # Get the days for this absence based on the start and end_date
        lappend absence_ids $absence_id
        set absence_days [concat $absence_days [im_absence_week_days -week_day_list $days_of_week -start_date $absence_start_date -end_date $absence_end_date]]
    }
    
    # Absence Days now contains all the dates which he has already off
    if {$type == "dates"} {
        return [lsort $absence_days]
    } elseif {$type == "sum"} {
        return [llength $absence_days]
    } elseif {$type == "absence_ids"} {
        return [lsort $absence_ids]
    }
}

ad_proc -public im_absence_calculate_absence_days {
    {-owner_id ""}
    {-group_ids ""}
    -start_date:required
    -end_date:required
    {-ignore_absence_ids ""}
    {-exclude_week_days {0 6}}
    {-type "duration"}
    {-absence_type_ids ""}
    {-absence_status_id ""}
} {
    Calculate the needed dates for an absence
    @param owner_id Owner for whom we calculate the actual absence
    @param group_ids Alternatively calculate for this group_ids. If neither group_ids nor owner_id is provided return absences for any group
    @param start_date Start of the absence
    @param end_date End of the absence
    @param ignore_absence_id Ignore this absence_id when calculating the dates. This is helpful if we edit an existing absence and want to get the other days the user is off
    @param type duration will return the sum of the days needed, dates will return the actual dates
} {
    
    # Get a list of dates in the range
    set dates_in_range [db_list date_range "
	SELECT to_char(i,'YYYY-MM-DD')
	FROM (
	      SELECT generate_series(start, finish, '1 day') AS i
	      FROM
	      (VALUES(
		      '$start_date'::date,
		      '$end_date'::date
		      )) AS t(\"start\", \"finish\")
	      ) AS j"]

    # Get the list of dates which are excluded
    if {$exclude_week_days eq ""} {
        set off_dates [list]
    } else {
        set off_dates [im_absence_week_days -week_day_list $exclude_week_days -start_date $start_date -end_date $end_date]
    }
    
    # Get the existing absence dates in the interval
    set existing_absence_dates [im_absence_dates -owner_id $owner_id -group_ids $group_ids -start_date $start_date -end_date $end_date -ignore_absence_ids $ignore_absence_ids -exclude_week_days $exclude_week_days -absence_type_ids $absence_type_ids -absence_status_id $absence_status_id]

    # Join the dates together
    set existing_absence_dates [concat $existing_absence_dates $off_dates]
    
    # Now check for each date in the range whether we need to take vacation then
    set required_dates [list]
    foreach date $dates_in_range {
        if {[lsearch $existing_absence_dates $date]<0} {
            lappend required_dates $date
        }
    }
    
    if {$type == "duration"} {
        return [llength $required_dates]
    } else {
        return [lsort $required_dates]
    }
}

ad_proc -public im_absence_update_duration_days {
    {-absence_id}
    {-exclude_week_days {0 6}}
    {-ignore_absence_ids ""}
} {
    db_1row absence_info "select to_char(start_date,'YYYY-MM-DD') as start_date, to_char(end_date,'YYYY-MM-DD') as end_date, owner_id, absence_type_id, duration_days as old_duration_days from im_user_absences where absence_id = :absence_id"
    
    lappend ignore_absence_ids $absence_id
    set duration_days [im_absence_calculate_absence_days -owner_id $owner_id -start_date $start_date -end_date $end_date -ignore_absence_ids $ignore_absence_ids -exclude_week_days $exclude_week_days]
    if {$duration_days != $old_duration_days} {
        db_dml update_duration "update im_user_absences set duration_days = :duration_days where absence_id = :absence_id"
        set wf_key [db_string wf "select trim(aux_string1) from im_categories where category_id = :absence_type_id" -default ""]
        set wf_exists_p [db_string wf_exists "select count(*) from wf_workflows where workflow_key = :wf_key"]
        if {$wf_exists_p} {
            set case_id [db_string case "select case_id from wf_cases where object_id = :absence_id"]
            #Record the change manually, as the workflow did fail (probably because the case is already closed
            im_workflow_new_journal -case_id $case_id -action "modify absence" -action_pretty "Modify Absence" -message "Absence was modified by [im_name_from_user_id [ad_conn user_id]], duration changed from $old_duration_days to $duration_days"
        }
        return "1"
    } else {
        return 0
    }
}

ad_proc -public im_absence_approval_component {
    -user_id:required
} {
    Returns a HTML component showing the vacations
    for the user
} {
    set current_user_id [ad_get_user_id]
    # This is a sensitive field, so only allows this for the user himself
    # and for users with HR permissions.

    set read_p 0
    if {$user_id == $current_user_id} { set read_p 1 }
    if {[im_permission $current_user_id view_hr]} { set read_p 1 }
    if {!$read_p} { return "" }

    set params [list \
		    [list user_id $user_id] \
		    [list return_url [im_url_with_query]] \
    ]

    set result [ad_parse_template -params $params "/packages/intranet-timesheet2/lib/absence-approval"]
    return [string trim $result]
}
