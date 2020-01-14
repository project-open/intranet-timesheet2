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
ad_proc -public im_user_absence_type_overtime {} { return 5006 }
ad_proc -public im_user_absence_type_reduction {} { return 5007 }
ad_proc -public im_user_absence_type_weekend {} { return 5008 }

ad_proc -public im_user_absence_status_active {} { return 16000 }
ad_proc -public im_user_absence_status_deleted {} { return 16002 }
ad_proc -public im_user_absence_status_requested {} { return 16004 }
ad_proc -public im_user_absence_status_rejected {} { return 16006 }



# ---------------------------------------------------------------------
# Absences Permissions
# ---------------------------------------------------------------------

ad_proc -public im_user_absence_permissions {user_id absence_id view_var read_var write_var admin_var} {
    Fill the "by-reference" variables read, write and admin
    with the permissions of $user_id on $absence_id. 
    Normally, a user is allowed to see and modify his own
    absences. Managers may gain additional rights with
    the privileges view_absences_all and view_absences_direct_reports.
    Absences under workflow control are a special case: Editing
    if normally not allowed, unless the user has the permission
    edit_absence_status.
} {
    upvar $view_var view
    upvar $read_var read
    upvar $write_var write
    upvar $admin_var admin

    set current_user_id $user_id
    set view 0
    set read 0
    set write 0
    set admin 0

    # Empty or bad absence_id
    if {"" == $absence_id || ![string is integer $absence_id]} { return "" }

    # Get cached absence info
    if {![db_0or1row absence_info "
	select	a.owner_id,
		a.group_id,
		a.vacation_replacement_id,
		(select count(*) from wf_cases wfc where wfc.object_id = a.absence_id) as wf_count
	from	im_user_absences a
	where	a.absence_id = $absence_id
    "]} {
	# Thic can happen if this procedure is called while the absence hasn't yet been created
	ns_log Error "im_user_absence_permissions: user_id=$user_id, absence_id=$absence_id: Absence not found"
	return
    }

    # Get cached permissions
    set add_absences_p [im_permission $current_user_id "add_absences"]
    set add_absences_all_p [im_permission $current_user_id "add_absences_all"]
    set add_absences_direct_reports_p [im_permission $current_user_id "add_absences_direct_reports"]
    set view_absences_p [im_permission $current_user_id "view_absences"]
    set view_absences_all_p [im_permission $current_user_id "view_absences_all"]
    set view_absences_direct_reports_p [im_permission $current_user_id "view_absences_direct_reports"]
    set edit_absence_status [im_permission $current_user_id "edit_absence_status"]

    # The owner and administrators can always read and write
    if {$current_user_id == $owner_id || $add_absences_all_p} {
	set read 1
	set write 1
    }

    # Vacation replacement and admins can always read
    if {$view_absences_all_p || $current_user_id == $vacation_replacement_id} {
	set read 1
    }

    # Certain managers can read/write the absences of their direct reports:
    if {!$read && $view_absences_direct_reports_p} {
	# Get the direct reports of current_user_id (cached in the library)
	set current_user_direct_reports [im_user_direct_reports_ids -user_id $current_user_id]
	if {[lsearch $current_user_direct_reports $owner_id] > -1} {
	    set read 1
	}
    }

    if {!$write && $add_absences_direct_reports_p} {
	# Get the direct reports of current_user_id (cached in the library)
	set current_user_direct_reports [im_user_direct_reports_ids -user_id $current_user_id]
	if {[lsearch $current_user_direct_reports $owner_id] > -1} {
	    set read 1
	}
    }

    # Absence under Workflow control: Don't allow to modify
    # outside the workflow
    if {$wf_count} {
	# Special permission for users to modify an absence 
	# even under workflow control
	if {!$edit_absence_status} {
	    set write 0
	}
    }

    if {!$read} { set write 0 }
    set view $read
    set admin $write
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
		$absence_type_l10n
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
	from	im_user_absences a,
		im_day_enumerator(now()::date - '7'::integer, now()::date) d
	where	owner_id = :user_id
		and a.start_date <= d.d
		and a.end_date >= d.d
    "]

    return [expr {$num_absences * $hours_per_absence}]
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

    set perm_hash(owner-$rej) {v r d w a}
    set perm_hash(owner-$req) {v r d}
    set perm_hash(owner-$act) {v r d}
    set perm_hash(owner-$del) {v r d}

    set perm_hash(assignee-$rej) {v r}
    set perm_hash(assignee-$req) {v r}
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

    ns_log Notice "im_absence_new_page_wf_perm_edit_button absence_id=$absence_id => $perm_set"
    return [expr {[lsearch $perm_set "w"] > -1}]
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



    ns_log Notice "im_absence_new_page_wf_perm_delete_button absence_id=$absence_id => $perm_set"
    return [expr {[lsearch $perm_set "d"] > -1}]
}


# ----------------------------------------------------------
# Set color scheme 
# ----------------------------------------------------------


ad_proc -public im_absence_color_table { } {
    Returns some HTML with a table with the colors of absences
} {
    set html "<div class=filter-title>[lang::message::lookup "" intranet-timesheet2.Absences_Color_Codes "Absences Color Codes"]</div>\n"
    append html "<table cellpadding='5' cellspacing='5'>\n"
    set col_sql "
	select	*
	from	im_categories
	where	category_type = 'Intranet Absence Type' and
		(enabled_p is null or enabled_p = 't')
	order by category_id
    "
    set index 0
    db_foreach cols $col_sql {
	set col [im_absence_type_color -absence_type_id $category_id]
	regsub -all " " $category "_" category_key
	set category_l10n [lang::message::lookup "" intranet-core.$category_key $category]
	append html "<tr><td bgcolor=\#$col>$category_l10n</td></tr>\n"
	incr index
    }

    append html "</table>\n"
    return $html
}



ad_proc -public im_absence_type_color { 
    {-absence_id ""}
    {-absence_type_id ""}
} {
    Returns the color for an absence or an absence_type_id.
    Calling this function with an absence_id is slow, please
    use the absence_type_id for more than just a few calls.
} {
    if {"" ne $absence_id} {
	set breach_p [im_security_alert_check_integer -location "im_absence_type_color" -value $absence_id]
	if {$breach_p} { return "" }
	set absence_type_id [util_memoize [list db_string absence "select absence_type_id from im_user_absences where absence_id = $absence_id" -default ""]]
    }

    return [util_memoize [list im_absence_type_color_helper -absence_type_id $absence_type_id] 3600]
}

ad_proc im_absence_type_color_helper { 
    {-absence_type_id ""}
} {
    Returns the color for an absence or an absence_type_id.
    Calling this function with an absence_id is slow, please
    use the absence_type_id for more than just a few calls.
} {
    # Check if color was explicitely set
    set color_list [util_memoize [list db_list_of_lists collist "select category_id, aux_string2 from im_categories where category_type = 'Intranet Absence Type'"]]
    foreach catid_col $color_list { set color_hash([lindex $catid_col 0]) [lindex $catid_col 1] }
    if {[info exists color_hash($absence_type_id)]} {
	set color $color_hash($absence_type_id)
	if {"" ne $color} { return $color }
    }

    # Just take the Nth element from the color list
    set color_list [im_absence_cube_color_list]
    set category_list [util_memoize [list db_list absence_category_list "select category_id from im_categories where category_type = 'Intranet Absence Type' and (enabled_p is null or enabled_p = 't') order by category_id"]]
    set idx [lsearch $category_list $absence_type_id]
    if {$idx < 0} {
	ns_log Error "im_absence_type_color: Didn't find absence_type_id=$absence_type_id in the list of absence types"
	return "CCCCC9"
    }

    set result [lindex $color_list $idx]
    if {"" eq $result} { return "CCCCC9" }
    return $result
}

ad_proc im_absence_cube_color_list { } {
    Returns the list of colors for the various types of absences
} {
    return [util_memoize im_absence_cube_color_list_helper]
}

ad_proc im_absence_cube_color_list_helper {
    {-default_color "CCCCC9"}
} {
    Returns the list of colors for the various types of absences
} {
    # Define default color set
    # The last color acts as a default value for additional colors.
    # Please use the aux_string2 field in im_categories to set custom colors!
    set color_list {
        EC9559
        E2849B
        53A7D8
        A185CB
        FFF956
	FF7F00
	00FF7F 
	00FFFF 
	007FFF 
	7F00FF 
	FF00FF 
	FF007F 
    }

    set absence_type_count [db_string atc "select count(*) from im_categories where category_type = 'Intranet Absence Type' and (enabled_p is null or enabled_p = 't')"]
    while {[llength $color_list] < $absence_type_count} {
	lappend color_list "CCCCC9"
    }
    return $color_list
}


ad_proc im_absence_mix_colors {
    absence_type_ids
} {
    Renders a single report cell. absence_type_ids may consist of
    multiple absences overlapping
} {
    if {"" == $absence_type_ids} { return "" }
    set hex_list {0 1 2 3 4 5 6 7 8 9 A B C D E F}
    set len [llength $absence_type_ids]
    set r 0
    set g 0
    set b 0

    # Mix the colors for each entry in "absence_type_ids"
    for {set i 0} {$i < $len} {incr i} {
	set v [lindex $absence_type_ids $i]

	# set col "FFFFFF"
	set col [im_absence_type_color -absence_type_id $v] 

	set r [expr $r + [lsearch $hex_list [string range $col 0 0]] * 16]
	set r [expr $r + [lsearch $hex_list [string range $col 1 1]]]
	
	set g [expr $g + [lsearch $hex_list [string range $col 2 2]] * 16]
	set g [expr $g + [lsearch $hex_list [string range $col 3 3]]]
	
	set b [expr $b + [lsearch $hex_list [string range $col 4 4]] * 16]
	set b [expr $b + [lsearch $hex_list [string range $col 5 5]]]
    }

    # Calculate the median
    set r [expr {$r / $len}]
    set g [expr {$g / $len}]
    set b [expr {$b / $len}]

    # Convert the RGB values back into a hex color string
    set color ""
    append color [lindex $hex_list [expr {$r / 16}]]
    append color [lindex $hex_list [expr {$r % 16}]]
    append color [lindex $hex_list [expr {$g / 16}]]
    append color [lindex $hex_list [expr {$g % 16}]]
    append color [lindex $hex_list [expr {$b / 16}]]
    append color [lindex $hex_list [expr {$b % 16}]]

    ns_log Notice "im_absence_mix_colors: absence_type_ids=$absence_type_ids, color=$color"
    return $color
}



ad_proc im_absence_cube_render_cell {
    absence_type_ids
} {
    Renders a single report cell, which might contain an 
    intersection of multiple type of absences.
} {
    set color [im_absence_mix_colors $absence_type_ids]
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
    {-user_department_id "" }
    {-user_selection "" }
    {-report_start_date "" }
    {-report_end_date "" }
    {-user_id_from_search "" }
} {
    Returns a rendered cube with a graphical absence display
    for users.
} {
    set current_user_id [ad_conn user_id]
    set user_url "/intranet/users/view"
    set date_format "YYYY-MM-DD"
    set bgcolor(0) " class=roweven "
    set bgcolor(1) " class=rowodd "
    set name_order [parameter::get -package_id [apm_package_id_from_key intranet-core] -parameter "NameOrder" -default 1]

    # ---------------------------------------------------------------
    # Limit the number of users and days
    # ---------------------------------------------------------------

    if {"" == $report_start_date || "2000-01-01" == $report_start_date} {
	set report_start_date [db_string start_date "select now()::date"]
    }

    if {"" == $report_end_date} {
	set report_end_date [db_string end_date "select :report_start_date::date + 21"]	
    }

    if {[catch {
	set num_days [db_string get_number_days "select (:report_end_date::date - :report_start_date::date)" -default 0]
	incr num_days
    } err_msg]} {
	set num_days 21
    }

    if {$num_days > 370} {
	return [lang::message::lookup "" intranet-timesheet2.AbsenceCubeNotShownGreateOneYear "Graphical view of absences only available for periods less than 1 year"]
    }

    if {-1 == $absence_type_id} { set absence_type_id "" }


    # ---------------------------------------------------------------
    # Calculate SQL
    # ---------------------------------------------------------------

    set criteria [list]
    if {"" != $absence_type_id && 0 != $absence_type_id} {
	lappend criteria "a.absence_type_id = '$absence_type_id'"
    }
    if {"" != $absence_status_id && 0 != $absence_status_id} {
	lappend criteria "a.absence_status_id = '$absence_status_id'"
    }

    # Compatibility fix:
    # Groups are passed on from /intranet-timesheet2/www/absences/index as integers 
    if { $user_selection eq [im_employee_group_id] } {
	set user_selection "employees"
    } elseif { $user_selection eq [im_freelance_group_id] } {
        set user_selection "providers"
    } elseif  { $user_selection eq [im_customer_group_id] } {
        set user_selection "customers"
    }

    switch $user_selection {
	"all" {
	    # Nothing.
	}
	"mine" {
	    lappend criteria "u.user_id = :current_user_id"
	}
	"employees" {
	    lappend criteria "u.user_id IN (
		select	m.member_id
		from	group_approved_member_map m
		where	m.group_id = [im_employee_group_id]
	    )"
	
	}
	"providers" {
	    lappend criteria "u.user_id IN (
		select	m.member_id 
		from	group_approved_member_map m 
		where	m.group_id = [im_freelance_group_id]
	    )"
	}
	"customers" {
	    lappend criteria "u.user_id IN (
		select	m.member_id
		from	group_approved_member_map m
		where	m.group_id = [im_customer_group_id]
	    )"
	}
	"direct_reports" {
	    lappend criteria "a.owner_id in (
		select employee_id from im_employees
		where (supervisor_id = :current_user_id OR employee_id = :current_user_id)
	    UNION
		select	e.employee_id 
		from	im_employees e,
			-- Select all departments where the current user is manager
			(select	cc.cost_center_id,
				cc.manager_id
			from	im_cost_centers cc,
				(select cost_center_code as code,
					length(cost_center_code) len
				from	im_cost_centers
				where	manager_id = :current_user_id
				) t
			where	substring(cc.cost_center_code for t.len) = t.code
			) tt
		where  (e.department_id = tt.cost_center_id
		       OR e.employee_id = tt.manager_id)
	    )"
	}  
	default  {
	    if {[string is integer $user_selection]} {
		lappend criteria "u.user_id = :user_selection"
	    } else {
		# error message in index.tcl
	    }
	}
    }

    set where_clause [join $criteria " and\n            "]
    if {$where_clause ne ""} {
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

	if {$date_weekday eq "Sat" || $date_weekday eq "Sun"} { set holiday_hash($date_date) [im_user_absence_type_weekend] } 
	lappend day_list [list $date_date $date_day_of_month $date_month $date_year]
    }


    # ---------------------------------------------------------------
    # Determine Left Dimension
    # ---------------------------------------------------------------

    set user_department_where ""
    if {"" != $user_department_id} { 
	set user_department_code [db_string dept_code "select im_cost_center_code_from_id(:user_department_id)" -default ""]
	set user_department_code_len [string length $user_department_code]
	set user_department_where "and u.user_id in (
	select	e.employee_id
	from	acs_objects o,
		im_cost_centers cc,
		im_employees e
	where	e.department_id = cc.cost_center_id and
		cc.cost_center_id = o.object_id and
		substring(cc.cost_center_code for :user_department_code_len) = :user_department_code
	)
       "
    }

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
		$user_department_where
	order by
		lower(im_name_from_user_id(u.user_id, $name_order))
    "]

    # Get list of categeory_ids to determine index - needed for color codes !!!
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
    
    # im_day_enumerator exludes end_date! 
    set report_end_date_enum [clock format [clock scan {+1 day} -base [clock scan $report_end_date] ] -format %Y-%m-%d]

    set absence_sql "
	-- Individual Absences per user
	select	a.absence_type_id,
		a.owner_id,
		d.d
	from	im_user_absences a,
		users u,
		(select im_day_enumerator as d from im_day_enumerator(:report_start_date, :report_end_date_enum)) d,
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
		(select im_day_enumerator as d from im_day_enumerator(:report_start_date, :report_end_date_enum)) d
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
	set value {}
	if {[info exists absence_hash($key)]} { set value $absence_hash($key) }
	set absence_hash($key) [lappend value $absence_type_id]
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
	append table_body "<tr $bgcolor([expr {$row_ctr % 2}])>\n"
	set user_id [lindex $user_tuple 0]
	set user_name [lindex $user_tuple 1]
	append table_body "<td><nobr><a href='[export_vars -base $user_url {user_id}]'>$user_name</a></td></nobr>\n"
	foreach day $day_list {
	    set date_date [lindex $day 0]
	    set key "$user_id-$date_date"
	    set value {}

	    # ad_return_complaint xx [array get absence_hash]
	    # ad_return_complaint xx [array get holiday_hash]

	    if {[info exists absence_hash($key)]} { set value $absence_hash($key) }
	    if {[info exists holiday_hash($date_date)]} { lappend value $holiday_hash($date_date) }
 
	    set cell [im_absence_cube_render_cell $value]

	    if {$user_id == 624} {
		ns_log Notice "intranet-absences-procs: key=$key, im_absence_cube_render_cell($value) -> $cell"
	    }

	    append table_body $cell
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

    # User needs to be Employee or Freelancer 
    if { ![im_user_is_employee_p $user_id_from_search] } { 
	if { [im_profile::member_p -profile_id [im_freelance_group_id] -user_id $user_id_from_search] } {
	    if { ![parameter::get -package_id [apm_package_id_from_key intranet-timesheet2] -parameter "AllowAbsencesForFreelancersP" -default 0]  } {
		return ""
	    }
	} else {
	    # User is neither a Freelancer nor an Employee
	    return ""
	}
    }

    set current_user_id [ad_conn user_id]
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


ad_proc -public im_absence_vacation_balance_component_ajax {
    -user_id_from_search:required
    { -show_new_absence_links_p 0}
} {
    Returns a HTML component for vacation management. 
    Allows viewing vacations for current, last and next year 
} {
    # User needs to be Employee or Freelancer 
    if { ![im_user_is_employee_p $user_id_from_search] } { 
	if { [im_profile::member_p -profile_id [im_freelance_group_id] -user_id $user_id_from_search] } {
	    if { ![parameter::get -package_id [apm_package_id_from_key intranet-timesheet2] -parameter "AllowAbsencesForFreelancersP" -default 0]  } {
		return ""
	    }
	} else {
	    # User is neither a Freelancer nor an Employee
	    return ""
	}
    }

    set current_user_id [ad_conn user_id]
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
    # Give user the possibility to create new absence for user shown from this portlet
    if { $show_new_absence_links_p } {
	append result "<br>[im_menu_ul_list "timesheet2_absences" [list user_id_from_search $user_id_from_search return_url "/intranet/users/view?user_id=$user_id_from_search"]]"
    }

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
		start_date >= to_date(sysdate::text,'yyyy-mm-dd')
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


ad_proc -public im_user_absence_nuke {
    { -current_user_id ""}
    absence_id
} {
    Delete an im_hour entry and depending objects.
    This function is currently only used by the REST interface
} {
    im_audit -user_id $current_user_id -object_id $absence_id -action before_nuke
    db_dml del_tokens "delete from wf_tokens where case_id in (
		select case_id from wf_cases where object_id = :absence_id
    )"
    db_dml del_case "delete from wf_cases where object_id = :absence_id"
    db_string absence_delete "select im_user_absence__delete(:absence_id)"
    return $absence_id
}


ad_proc -public im_absence_vacation_balance_component_xhtml {
    -user_id_from_search:required
} {
    Returns a HTML component for vacation management.
    Allows viewing vacations for current, last and next year
} {
    ns_log Notice "Deprecated proc im_absence_vacation_balance_component_xhtml used, please use im_absence_vacation_balance_component_ajax"
    return [im_absence_vacation_balance_component_ajax -user_id_from_search $user_id_from_search]
}



ad_proc -public im_menu_absences_admin_links {

} {
    Return a list of admin links to be added to the "absences" menu
} {
    set result_list {}
    set current_user_id [ad_conn user_id]
    set return_url [im_url_with_query]

    # Append user-defined menus
    set bind_vars [list return_url $return_url]
#    set links [im_menu_ul_list -no_uls 1 -list_of_links 1 "timesheet2_absences" $bind_vars]
#    foreach link $links { lappend result_list $link }

    if { [im_is_user_site_wide_or_intranet_admin $current_user_id] } {
	lappend result_list [list [lang::message::lookup "" intranet-timesheet2.Export_Absences_to_CSV "Export Absences to CSV"] [export_vars -base "/intranet-dw-light/absence.csv" {return_url}]]
	lappend result_list [list [lang::message::lookup "" intranet-timesheet2.Import_Absences_from_CSV "Import Absences from CSV"] [export_vars -base "/intranet-csv-import/index" {{object_type im_user_absence} return_url}]]
    }

    return $result_list
}



ad_proc -public im_absence_formatted_duration_to_days {
    days_formatted
} {
    Converts a time string to days.
    Examples: '1 day', '4 hours', '1' (=one day), '0.5' (=half a day)
} {
    set days_formatted_1 [string trim [string tolower $days_formatted]]
    set days_formatted_2 [string map {days d day d hours h hour h} $days_formatted_1]

    set days ""
    if {[regexp {^(.+)d} $days_formatted_2 match day_string]} { 
	catch {
	    set days [expr 1.0 * [string trim $day_string]]
	}
    }
    if {[regexp {^(.+)h} $days_formatted_2 match hour_string]} { 
	catch {
	    set days [expr [string trim $hour_string] / 8.0]
	}
    }
    if {"" eq $days} { 
	catch {
	    set days [expr 1.0 * $days_formatted_2]
	}
    }

    return $days
}



ad_proc -public im_absences_assign_vacation_replacement {
    -task_id
} {
    Assigns a vacation replacement to a task
} {
    set current_user_id [ad_conn user_id]

    # ---------------------------------------------------------------------
    # Does the assigned user have an absence currently?
    #
    set assignee_html ""
    set assignee_sql "
	select	ua.vacation_replacement_id
	from	wf_tasks t,
		wf_task_assignments ta,
		im_user_absences ua
	where	t.task_id = :task_id and
		ta.task_id = t.task_id and
		ta.party_id = ua.owner_id and
		now()::date between ua.start_date and ua.end_date
    "
    db_foreach assignee $assignee_sql {
        if {$current_user_id eq $vacation_replacement_id} {
	    db_string wf_assig "select workflow_case__add_task_assignment (:task_id, :vacation_replacement_id, 'f')"
	}
    }
}


