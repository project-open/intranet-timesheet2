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
ad_proc -public im_user_absence_type_rwh {} { return 5007 }
ad_proc -public im_user_absence_type_bridge_day {} { return 5008 }
ad_proc -public im_user_absence_type_weekend {} { return 5009 }


ad_proc -public im_user_absence_status_active {} { return 16000 }
ad_proc -public im_user_absence_status_deleted {} { return 16002 }
ad_proc -public im_user_absence_status_requested {} { return 16004 }
ad_proc -public im_user_absence_status_rejected {} { return 16006 }


# ---------------------------------------------------------------------
# Helper procs
# ---------------------------------------------------------------------

ad_proc get_value_if {someVar {default_value ""}} {
    @author Neophytos Demetriou (neophytos@azet.sk)
} {
    upvar $someVar var
    if {[info exists var]} { 
        return $var
    }
    return $default_value
}

ad_proc im_seconds_from_date {date} {
    @author Neophytos Demetriou (neophytos@azet.sk)
} {
    return [db_string seconds "select EXTRACT(EPOCH FROM TIMESTAMP WITH TIME ZONE :date)"]
}

ad_proc im_year_from_date {date} {
    @author Neophytos Demetriou (neophytos@azet.sk)
} {

    if { $date eq {} } {
        return
    }

    return [clock format [im_seconds_from_date $date] -format "%Y"]
}

ad_proc incr_if {varName expr} {
    @author Neophytos Demetriou (neophytos@azet.sk)
} {
    upvar $varName var
    if { [uplevel [list expr $expr]] } {
        incr var
    }
}

ad_proc im_coalesce {args} {
    @author Neophytos Demetriou (neophytos@azet.sk)
} {
    return [lsearch -inline -not $args {}]
}

ad_proc im_intersect3 {a b} {
    from tcl wiki (http://wiki.tcl.tk/283)
} {

    if {[llength $a] == 0} {
        return [list {} {} $b]
    }
    if {[llength $b] == 0} {
        return [list {} $a {}]
    }

    set res_i  {}
    set res_ab {}
    set res_ba {}

    foreach e $b {
        set ba($e) .
    }

    foreach e $a {
        set aa($e) .
    }

    foreach e $a {
        if {![info exists ba($e)]} {
            lappend res_ab $e
        } else {
            lappend res_i $e
        }
    }

    foreach e $b {
        if {![info exists aa($e)]} {
            lappend res_ba $e
        } else {
            lappend res_i $e
        }
    }

    list $res_i $res_ab $res_ba

}

ad_proc im_name_from_id {object_id} {
    @author Neophytos Demetriou (neophytos@azet.sk)
} {

    # we check to make sure the given id is an integer
    # as we don't db quote the value, if it's quoted
    # it just returns the provided value as is
    # if substituted, pl/pgsql figures out it's an 
    # integer and picks the right function (the one
    # that accepts an integer)
    if { ![string is integer -strict $object_id] } {
        error "object_id must be an integer value"
    }

    set name [db_string get_name_from_id "select im_name_from_id($object_id) as name" -default "xyz"] 

    return $name

}


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
            (select count(1) from wf_cases wfc where wfc.object_id = a.absence_id) as wf_count
        from	im_user_absences a
        where	a.absence_id = :absence_id
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

        set sql "
            select true 
            from wf_cases wfc 
            inner join wf_user_tasks ut
            on (ut.case_id=wfc.case_id)
            where wfc.object_id = :absence_id
            and ut.user_id = :current_user_id
            limit 1
        "

        set assigned_to_user_p [db_string assigned_to_user_p $sql -default false]

        if { $assigned_to_user_p } { 
            set read 1
            set write 1
        }
    }


    if {!$read} { set write 0 }
    set view $read
    set admin $write
}


ad_proc absence_list_for_user_and_time_period {
    {-only_active:boolean}
    user_id first_julian_date last_julian_date} {
    For a given user and time period, this proc returns a list 
    of elements where each element corresponds to one day and describes its
    "work/vacation type".
} {
    
    if {$only_active_p} {append active_sql "and absence_status_id in ([template::util::tcl_to_sql_list [im_sub_categories [im_user_absence_status_active]]])"} else {set active_sql ""}
    
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
        $active_sql
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
        $active_sql
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
    set del [im_user_absence_status_deleted]
    
    foreach act_cat_id [im_sub_categories [im_user_absence_status_active]] {
        set perm_hash(owner-$act_cat_id) {v r d}
        set perm_hash(assignee-$act_cat_id) {v r}
        set perm_hash(hr-$act_cat_id) {v r d w a}    
    }
    
    set perm_hash(owner-$rej) {v r}
    set perm_hash(owner-$req) {v r d w}
    set perm_hash(owner-$del) {v r}

    set perm_hash(assignee-$rej) {v r w}
    set perm_hash(assignee-$req) {v r w}
    set perm_hash(assignee-$del) {v r}

    set perm_hash(hr-$rej) {v r d w a}
    set perm_hash(hr-$req) {v r d w a}
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

ad_proc im_absence_fg_color {
   col
} {
    moved from im_absence_cube_legend
} {

    if { [string length $col] == 6} {
        # Transform RGB Hex-Values (e.g. #a3b2c4) into Dec-Values
        set r_bg [expr 0x[string range $col 0 1]]
        set g_bg [expr 0x[string range $col 2 3]]
        set b_bg [expr 0x[string range $col 4 5]]
    } elseif { [string length $col] == 3 } {
        # Transform RGB Hex-Values (e.g. #a3b) into Dec-Values
        set r_bg [expr 0x[string range $col 0 0]]
        set g_bg [expr 0x[string range $col 1 1]]
        set b_bg [expr 0x[string range $col 2 2]]
    } else {
        # color codes can't be parsed -> set a middle value
        set r_bg 127
        set g_bg 127
        set b_bg 127
    }
    # calculate a brightness-value for the color
    # if brightness > 127 the foreground color is black, if < 127 the foreground color is white
    set brightness [expr $r_bg * 0.2126 + $g_bg * 0.7152 + $b_bg * 0.0722]
    set col_fg "fff"
    if {$brightness >= 127} {set col_fg "000"}

    return $col_fg
}

ad_proc im_absence_render_cell {
    bg_color
    {fg_color "#fff"}
    {str "&nbsp;"}
    {align "center"}
    {extra_style "padding:3px;"}
} {
    Renders a single report cell, depending on value.
    Takes the color from absences color lookup.
} {
    if { $bg_color ne {} } {
        return "<td style='text-align:${align}; background-color:\#$bg_color; color:\#$fg_color;${extra_style}'>$str</td>"
    } else {
        return "<td>&nbsp;</td>\n"
    }
}

ad_proc -public im_absence_day_list {
    {-date_format:required}
    {-num_days:required}
    {-start_date:required}
} {
    get a day_list
} {
    return [util_memoize \
        [list im_absence_day_list_helper \
            -date_format $date_format \
            -num_days $num_days \
            -start_date $start_date]]
}

ad_proc -public im_absence_day_list_helper {
    {-date_format:required}
    {-num_days:required}
    {-start_date:required}
} {
    get a day_list
} {
        
    set day_list [list]
    for {set i 0} {$i < $num_days} {incr i} {
        db_1row date_info "
        	    select 
        		to_char(:start_date::date + :i::integer, :date_format) as date_date,
        		to_char(:start_date::date + :i::integer, 'Day') as date_day,
        		to_char(:start_date::date + :i::integer, 'dd') as date_day_of_month,
        		to_char(:start_date::date + :i::integer, 'Mon') as date_month,
        		to_char(:start_date::date + :i::integer, 'YYYY') as date_year,
        		to_char(:start_date::date + :i::integer, 'Dy') as date_weekday
                "

        set date_month [lang::message::lookup "" intranet-timesheet2.$date_month $date_month]
        lappend day_list [list $date_date $date_day_of_month $date_month $date_year]
    }
    return $day_list
}


ad_proc -private im_absence_component_view_p {
    -user_selection:required 
} {

    Returns true if the current user (current_user_id) can view the 
    absence component (Absence Cube, Absence Calendar) of another 
    user (owner_id).

    Only allows this for the owner, for users with HR permissions,
    supervisor of the employee, and the cost center (department) manager.

    @author Neophytos Demetriou (neophytos@azet.sk)
} {

    set current_user_id [ad_get_user_id]

    return \
        [im_absence_component__user_selection_helper \
            -user_selection $user_selection \
            -user_selection_idVar user_selection_id \
            -user_selection_typeVar user_selection_type]

}

ad_proc im_absence_component__timescale_types {} {
    @last-modified 2014-11-24
    @last-modified-by Neophytos Demetriou (neophytos@azet.sk)
} {

# all "ALL" might have to be added later
    set types {
        today "Today"
        next_3w "Next 3 Weeks"
        next_3m "Next 3 Months"
        future "Future"
        past "Past"
        last_3m "Last 3 Months"
        last_3w "Last 3 Weeks"
    }

    set options [list]
    foreach {value label} $types {
        set msg_name [string map {" " "_"} $label]
        lappend options [list [lang::message::lookup "" intranet-timesheet2.$msg_name $label] $value]
    }
    return $options
}


ad_proc -private im_where_from_criteria {
    criteria 
    {keyword "and"}
} {
    @last-modified 2014-11-24
    @last-modified-by Neophytos Demetriou (neophytos@azet.sk)
} {
    set where_clause ""
    if { $criteria ne {} } {
        set where_clause "\n\t${keyword} [join $criteria "\n\tand "]"
    }
    return $where_clause
}

ad_proc -private im_absence_component__absence_criteria {
    -where_clauseVar:required
    -user_selection:required
    {-absence_type_id ""}
    {-absence_status_id ""}
} {
    @last-modified 2014-12-08
    @last-modified-by Neophytos Demetriou (neophytos@azet.sk)
} {

    upvar $where_clauseVar where_clause

    set criteria [list]

    im_absence_component__user_selection_helper \
        -user_selection $user_selection \
        -user_selection_idVar user_selection_id \
        -user_selection_typeVar user_selection_type \
        -hide_colors_pVar hide_colors_p

    if {$hide_colors_p} {
        # show only approved and requested
        set absence_status_id [list [im_user_absence_status_active],[im_user_absence_status_requested]]
    } else {
        if { $absence_status_id ne {} } {
            if { [llength $absence_status_id] == 1 } {
                lappend criteria "a.absence_status_id in ([template::util::tcl_to_sql_list [im_sub_categories $absence_status_id]])"
            } else {
                lappend criteria "a.absence_status_id in ([template::util::tcl_to_sql_list $absence_status_id])"
            }
        }
    }

    if { $absence_type_id ne {} && $absence_type_id > "0" } {
        lappend criteria "a.absence_type_id = :absence_type_id"
    }

    # temporary hack until I manage to refactor the code
    append where_clause [db_bind_var_substitution [im_where_from_criteria $criteria]]

}

ad_proc -private im_absence_component__user_selection_helper {
    -user_selection:required
    -user_selection_idVar:required
    -user_selection_typeVar:required
    {-hide_colors_pVar ""}
    {-user_nameVar ""}
} {
    Returns true if the current user can view the given selection. 
    Otherwise, it returns false. 
    
    @last-modified 2014-11.24
    @last-modified-by Neophytos Demetriou (neophytos@azet.sk)
} {

    upvar $user_selection_idVar user_selection_id
    upvar $user_selection_typeVar user_selection_type

    if {$user_nameVar ne {}} {
        upvar $user_nameVar user_name
    }

    if {$hide_colors_pVar ne {}} {
        upvar $hide_colors_pVar hide_colors_p
    }

    set user_selection_id ""
    set user_selection_type ""
    set user_name ""
    set hide_colors_p 0

    set current_user_id [ad_get_user_id]

    set can_add_all_p [im_permission $current_user_id "add_absences_all"]
    set can_view_all_p [expr { [im_permission $current_user_id "view_absences_all"] || $can_add_all_p }]

    # user_selection is required to be an integer
    # returns false, no one can view the component
    # with a non-integer selection
    if { [string is integer -strict $user_selection] } {

        # Figure out the object_type for the given object id, i.e. user_selection.
        set sql "select object_type from acs_objects where object_id = :user_selection"
        set object_type [db_string object_type $sql -default ""]

        switch $object_type {

            im_cost_center {

                set user_name [im_cost_center_name $user_selection]
                if {[im_manager_of_cost_center_p -user_id $current_user_id -cost_center_id $user_selection] || $can_view_all_p} {
                    # allow managers to view absences in their department
                    set user_selection_type "cost_center"
                    set user_selection_id $user_selection
                } else {
                    return false
                }

            }

            user {

                set user_name [im_name_from_user_id $user_selection]
                set user_selection_type user
                set user_selection_id $user_selection
                
                # Show only if user is an employee
                set owner_id $user_selection_id
                if { ![im_user_is_employee_p $owner_id] } { return false }

                set sql "
                    select supervisor_id,manager_id
                    from im_employees e
                    inner join im_cost_centers cc
                    on (cc.cost_center_id=e.department_id)
                    where employee_id = :owner_id
                "
                set exists_p [db_0or1row supervisor_and_cc_manager $sql]

                if { !$exists_p } { return false }

                set read_p 0
                incr_if read_p {[im_permission $current_user_id "view_absences_all"]}
                incr_if read_p {[im_user_is_hr_p [ad_conn user_id]]}
                incr_if read_p {$owner_id == $current_user_id}
                incr_if read_p {$supervisor_id == $current_user_id}

                if { !$read_p } {
                    set hide_colors_p 1
                }

                incr_if read_p {$manager_id == $current_user_id}
                return $read_p

            }

            im_project {

                set project_manager_p [im_biz_object_member_p -role_id 1301 $current_user_id $user_selection]
                if {$project_manager_p || $can_view_all_p} {
                    set user_name [db_string project_name "select project_name from im_projects where project_id = :user_selection" -default ""]
                    set hide_colors_p 1
                    set user_selection_type "project"
                    set user_selection_id $user_selection
                } else {
                    return false
                }

            }

            default {
                ad_return_complaint 1 "Invalid User Selection:<br>Value '$user_selection' is not a user_id, project_id, department_id or one of {mine|all|employees|providers|customers|direct reports}."
                return false
            }

        }
    } else {

        set add_absences_for_group_p [im_permission $current_user_id "add_absences_for_group"]
        set add_absences_all_p [im_permission $current_user_id "add_absences_all"]
        set view_absences_all_p [expr [im_permission $current_user_id "view_absences_all"] || $can_add_all_p]
        set add_absences_p [im_permission $current_user_id "add_absences"]

        switch $user_selection {
            mine { 
                set user_selection_id $current_user_id
                set user_selection_type user
                return true
            }
            all  -
            employees -
            providers -
            customers {
                set user_selection_type $user_selection
                return $can_view_all_p
            }
            {direct_reports} {

                set user_selection_type "direct_reports"

                set can_add_absences_direct_reports_p \
                    [im_permission $current_user_id "add_absences_direct_reports"]

                set can_view_absences_direct_reports_p \
                    [expr [im_permission $current_user_id "view_absences_direct_reports"] || $can_add_absences_direct_reports_p]

                return $can_view_absences_direct_reports_p

            }
        }

    }

    return true
}


ad_proc -private im_absence_component__user_selection {
    -where_clauseVar:required
    -user_selection:required
    -hide_colors_pVar:required
    {-user_selection_column "a.owner_id"}
    {-user_selection_typeVar ""}
    {-total_countVar ""}
    {-is_aggregate_pVar ""}
    {-im_where_from_criteria_keyword "and"}
} {
    @last-modified 2014-12-09
    @last-modified-by Neophytos Demetriou (neophytos@azet.sk)
} {

    upvar $where_clauseVar where_clause
    upvar $hide_colors_pVar hide_colors_p
    if { $user_selection_typeVar ne {} } {
        upvar $user_selection_typeVar user_selection_type
    }
    if { $total_countVar ne {} } {
        upvar $total_countVar total_count
    }
    if { $is_aggregate_pVar ne {} } {
        upvar $is_aggregate_pVar is_aggregate_p
    }

    im_absence_component__user_selection_helper \
        -user_selection $user_selection \
        -user_selection_idVar user_selection_id \
        -user_selection_typeVar user_selection_type \
        -hide_colors_pVar hide_colors_p

    set criteria [list]

    set current_user_id [ad_get_user_id]

    set is_aggregate_p 0
    set total_count ""

    switch $user_selection_type {

        "all" {
            # Nothing.
            if { $total_countVar ne {} } {
                set total_count [db_string total_count "select count(1) from im_employees"]
            }
            set is_aggregate_p 1
        }

        "mine" {
            lappend criteria "${user_selection_column} = :current_user_id"
        }

        "employees" {

           set sql "
                select	m.member_id
                from	group_approved_member_map m
                where	m.group_id = [im_employee_group_id]
            "

            lappend criteria "${user_selection_column} IN (${sql})"

            if { $total_countVar ne {} } {
                set total_count [db_string total_count "select count(1) from ($sql) t"]
            }

            set is_aggregate_p 1

        }

        "providers" {

            set sql "
                select	m.member_id 
                from	group_approved_member_map m 
                where	m.group_id = [im_freelance_group_id]
            "

            lappend criteria "${user_selection_column} IN (${sql})"

            if { $total_countVar ne {} } {
                set total_count [db_string total_count "select count(1) from ($sql) t"]
            }

            set is_aggregate_p 1

        }

        "customers" {

            set sql "
                select	m.member_id
                from	group_approved_member_map m
                where	m.group_id = [im_customer_group_id]
            "

            lappend criteria "${user_selection_column} IN (${sql})"

            if { $total_countVar ne {} } {
                set total_count [db_string total_count "select count(1) from ($sql) t"]
            }

            set is_aggregate_p 1

        }

        "direct_reports" {

            set sql "
                select employee_id from im_employees
                where (supervisor_id = :current_user_id OR employee_id = :current_user_id)
            "

            lappend criteria "${user_selection_column} in (${sql})"

            if { $total_countVar ne {} } {
                set total_count [db_string total_count "select count(1) from ($sql) t"]
            }


            set is_aggregate_p 1

        }  

        "cost_center" {

            set cost_center_id $user_selection_id
            set cost_center_list [im_cost_center_options -parent_id $cost_center_id]
            set cost_center_ids [list $cost_center_id]
            foreach cost_center $cost_center_list {
                lappend cost_center_ids [lindex $cost_center 1]
            }

            set sql "
                select employee_id 
                from im_employees 
                where department_id in ([template::util::tcl_to_sql_list $cost_center_ids]) 
                and employee_status_id = [im_employee_status_active] 
                UNION
                select :current_user_id from dual
            "

            lappend criteria "${user_selection_column} in (${sql})"

            if { $total_countVar ne {} } {
                set total_count [db_string total_count "select count(1) from ($sql) t"]
            }

            set is_aggregate_p 1

        }

        "project" {

            set project_id $user_selection_id
            set project_ids [im_project_subproject_ids -project_id $project_id]
            set sql "
                select object_id_two 
                from acs_rels 
                where object_id_one in ([template::util::tcl_to_sql_list $project_ids])
            "

            lappend criteria "${user_selection_column} in (${sql})"

            if { $total_countVar ne {} } {
                set total_count [db_string total_count "select count(1) from ($sql) t"]
            }

            set is_aggregate_p 1

        }

        "user" {
            set user_id $user_selection_id
            lappend criteria "${user_selection_column}=:user_id"
        }	    

        default  {
            # We shouldn't even be here, so just display his/her own ones
            lappend criteria "${user_selection_column} = :current_user_id"
        }

    }

    # temporary hack until I manage to refactor the code
    append where_clause [db_bind_var_substitution [im_where_from_criteria $criteria $im_where_from_criteria_keyword]]


}

ad_proc im_absence_component__timescale {
    {-where_clauseVar ""}
    {-start_dateVar ""}
    {-end_dateVar ""}
    {-where_clauseVar ""}
    {-num_daysVar ""}
    -timescale_date:required
    -timescale:required
} {
    @last-modified 2014-11-24
    @last-modified-by Neophytos Demetriou (neophytos@azet.sk)
} {

    foreach myVar {where_clause start_date end_date num_days} {
        set otherVar "${myVar}Var"
        if { [set $otherVar] ne {}} {
            upvar [set $otherVar] $myVar
        }
    }

    set criteria [list]

    set today_date [db_string today "select now()::date"]
    if {$timescale_date eq {}} {
	set timescale_date $today_date
    }

    set num_days ""
    set start_date $timescale_date
    set end_date $timescale_date
    switch $timescale {
        "all" {
	    # Limit the display to 365 days back and forward as you can always change by start date.
            set num_days 365
	    set start_date [db_string all "select to_date(:timescale_date,'YYYY-MM-DD') - :num_days::integer"]
	    set end_date [db_string all "select to_date(:timescale_date,'YYYY-MM-DD') + :num_days::integer"]
        }
        "today" { 
            set num_days 1
            set end_date $timescale_date
        }
        "next_3w" { 
            set num_days 21 
            set end_date [db_string 3w "select to_date(:timescale_date,'YYYY-MM-DD') + :num_days::integer"]
        }
        "last_3w" { 
            set num_days -21 
            set end_date $timescale_date
            set start_date [db_string 3w "select to_date(:timescale_date,'YYYY-MM-DD') + :num_days::integer"]
        }
        "past" { 
	    # Limit to the last 6 months, if you need to go further, change start date
            set num_days 185
	    set start_date [db_string past "select to_date(:timescale_date,'YYYY-MM-DD') - :num_days::integer"]
        }
        "future" { 
	    # We assume noone has planing ahead for more then one year, otherwise change start_date
            set num_days 365
	    set end_date [db_string future "select to_date(:timescale_date,'YYYY-MM-DD') + :num_days::integer"]
        }
        "last_3m" { 
            set num_days -93 
            set end_date $start_date
            set start_date [db_string 3w "select to_date(:timescale_date,'YYYY-MM-DD') + :num_days::integer"]
        }
        "next_3m" { 
            set num_days 93 
            set end_date [db_string 3w "select to_date(:timescale_date,'YYYY-MM-DD') + :num_days::integer"]
        }
        default {
            set num_days 21
        }
    }

    # Limit to start-date and end-date
    if {$start_date ne {}} { lappend criteria "a.end_date::date >= :start_date" }
    if {$end_date ne {}} { lappend criteria "a.start_date::date <= :end_date" }

    # Hard Limit for the start_date 
    set max_days [parameter::get -parameter HideAbsencesOlderThanDays -default "365"]
    set max_days_interval "$max_days days"
    lappend criteria "a.start_date::date > now() - :max_days_interval::interval"

    # temporary hack until I manage to refactor the code
    append where_clause [db_bind_var_substitution [im_where_from_criteria $criteria]]

}


ad_proc im_absence_component__order_by_clause {order_by} {
    @last-update 2014-11-24
    @modifying-user Neophytos Demetriou (neophytos@azet.sk)
} {
    set order_by_clause ""
    switch $order_by {
        "Name" { set order_by_clause "order by upper(absence_name), owner_name" }
        "User" { set order_by_clause "order by owner_name, start_date" }
        "Date" { set order_by_clause "order by start_date, owner_name" }
        "Start" { set order_by_clause "order by start_date" }
        "End" { set order_by_clause "order by end_date" }
        "Type" { set order_by_clause "order by absence_type, owner_name" }
        "Status" { set order_by_clause "order by absence_status, owner_name" }
    }
    return $order_by_clause
}


ad_proc -private im_supervisor_of_employee_p {
    -supervisor_id
    -employee_id
} {
    @author Neophytos Demetriou (neophytos@azet.sk)
} {
    set sql "select true from im_employees where employee_id=:employee_id and supervisor_id=:supervisor_id"
    return [db_string supervisor_p $sql -default false]
}

ad_proc -private im_manager_of_employee_p {
    -manager_id
    -employee_id
} {
    @author Neophytos Demetriou (neophytos@azet.sk)
} {
    set sql "
        select true 
        from im_employees e 
        inner join im_cost_centers cc 
        on (cc.cost_center_id=e.department_id) 
        where employee_id=:employee_id and manager_id=:supervisor_id
    "
    return [db_string supervisor_p $sql -default false]
}

ad_proc -public im_absence_cube_component {
    -user_selection:required
    {-absence_status_id "" }
    {-absence_type_id "" }
    {-timescale "next_3w" }
    {-timescale_date "" }
    {-hide_colors_p 0}
} {

    Makes use of im_absence_cube to return a rendered cube with 
    a graphical absence display for users.

    Copied and modified im_absence_vacation_balance_component to
	ensure that it parses the include in a similar manner.

} {

    if {$timescale_date eq {}} {
        set timescale_date [db_string today "select now()::date"]
    }

    if { ![im_absence_component_view_p -user_selection $user_selection] } {
#        return "You do not have enough privileges to view this component"
	return ""
    }

    set params [list \
		    [list user_selection $user_selection] \
			[list absence_status_id $absence_status_id] \
			[list absence_type_id $absence_type_id] \
			[list timescale $timescale] \
			[list timescale_date $timescale_date] \
			[list user_selection $user_selection] \
			[list hide_colors_p $hide_colors_p] \
		    [list return_url [im_url_with_query]] \
    ]

    set result [ad_parse_template -params $params "/packages/intranet-timesheet2/lib/absence-cube"]
    return [string trim $result]
}

ad_proc -public im_absence_list_component {
    -user_selection:required
    {-absence_status_id "" }
    {-absence_type_id "" }
    {-timescale "" }
    {-timescale_date "" }
    {-hide_colors_p 0}
    {-order_by ""}
} {

    @last-modified 2014-11-24
    @last-modified-by Neophytos Demetriou (neophytos@azet.sk)

} {

    if { ![im_absence_component_view_p -user_selection $user_selection] } {
#        return "You do not have enough privileges to view this component"
	return ""
    }

    set params [list \
			[list user_selection $user_selection] \
			[list absence_status_id $absence_status_id] \
			[list absence_type_id $absence_type_id] \
			[list timescale $timescale] \
			[list timescale_date $timescale_date] \
			[list hide_colors_p $hide_colors_p] \
			[list order_by $order_by] \
		    [list return_url [im_url_with_query]] \
    ]

    set result [ad_parse_template -params $params "/packages/intranet-timesheet2/lib/absences-list"]
    return [string trim $result]
}


ad_proc -public im_absence_calendar_component {
    {-owner_id ""}
    {-year ""}
    {-absence_status_id "" }
    {-absence_type_id "" }
    {-hide_explanation_p "0"}
} {

   Displays a yearly calendar of absences for a user. 
   Uses the same color coding as the absence cube, but
   instead of displaying multiple users, it works only 
   for one user.

} {

    if { $year eq {} } {
        set year [clock format [clock seconds] -format "%Y"]
    }

    set user_selection $owner_id
    set current_user_id [ad_get_user_id]
    if { ![im_absence_component_view_p -user_selection $user_selection] } {
#        return "You do not have enough privileges to view this component"
	return ""
    }

    set params \
        [list \
		    [list user_selection $user_selection] \
			[list year $year] \
			[list absence_status_id $absence_status_id] \
			[list absence_type_id $absence_type_id] \
            [list hide_explanation_p $hide_explanation_p]]

    set result [ad_parse_template -params $params "/packages/intranet-timesheet2/lib/absence-calendar"]
    return [string trim $result]
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
    if { ![im_absence_component_view_p -user_selection $user_id] } {
#        return "You do not have enough privileges to view this component"
	return "" ; # Returning nothing will hide the component. Horray!
    }

    set params [list \
		    [list user_id_from_search $user_id] \
		    [list return_url [im_url_with_query]] \
    ]

    set result [ad_parse_template -params $params "/packages/intranet-timesheet2/lib/user-absences"]
    return [string trim $result]
}

ad_proc -public im_absence_info_component {
    -absence_id:required
} {
    Returns a HTML component showing the info about an absence
} {
    set current_user_id [ad_get_user_id]


    set params [list \
		    [list absence_id $absence_id] \
		    [list return_url [im_url_with_query]] \
    ]

    set result [ad_parse_template -params $params "/packages/intranet-timesheet2/lib/absence-info"]
    return [string trim $result]
}

ad_proc -public im_absence_balance_component {
    -user_id:required
} {
    Returns a HTML component showing the absence balance for a user
} {

    set params [list \
		    [list user_id $user_id] \
		    [list return_url [im_url_with_query]] \
    ]

    set result [ad_parse_template -params $params "/packages/intranet-timesheet2/lib/absence-balance-component"]
    return [string trim $result]
}

ad_proc -public im_absence_remaining_days {
    -user_id:required
    -absence_type_id:required
    -approved:boolean
    {-ignore_absence_ids ""}
    {-booking_date ""}
} {
    Returns the number of remaining days for the user of a certain absence type
    @param ignore_absence_id Ignore this absence_id when calculating the remaining days.
    @param booking_date Parameter to be used for leave entitlements to define which leave entitlements should be included. Defaults to current date (everything earned up until today)
} {
    if {[im_table_exists im_user_leave_entitlements]} {
	    return [im_leave_entitlement_remaining_days -user_id $user_id -absence_type_id $absence_type_id -approved_p $approved_p -ignore_absence_ids $ignore_absence_ids -booking_date $booking_date]
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
    return [util_memoize [list im_absence_week_days_helper -start_date $start_date -end_date $end_date -week_day_list $week_day_list -type $type]]
}

ad_proc -public im_absence_week_days_helper {
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
    # Assume current year for start/enddate
    set current_year [dt_systime -format "%Y"]
    if {$start_date eq ""} {
        set start_date "${current_year}-01-01"
    }
    if {$end_date eq ""} {
	    set end_date "${current_year}-12-31"
    }

    # If we have an owner_id limit the absences to only this owner and the group the owner belongs to
    
    if {$owner_id ne ""} {
        # Get the groups the owner belongs to
        set group_ids [im_biz_object_memberships -member_id $owner_id]

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
        set absence_status_sql "absence_status_id in ([template::util::tcl_to_sql_list [im_sub_categories $absence_status_id]])"
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
                where   (start_date::date <= :end_date and
                        end_date::date >= :start_date and
                        $absence_status_sql
                        $absence_type_sql
                        $owner_sql)
                        $ignore_absence_sql
                        " {
        # Get the days for this absence based on the start and end_date
        lappend absence_ids $absence_id
        set absence_days [concat $absence_days [im_absence_week_days -week_day_list $days_of_week -start_date $absence_start_date -end_date $absence_end_date]]
    }
     
    # Remove duplicates
    set absence_days [lsort -unique $absence_days]
    
    # Absence Days now contains all the dates which he has already off
    if {$type == "dates"} {
        return [lsort $absence_days]
    } elseif {$type == "sum"} {
        return [llength $absence_days]
    } elseif {$type == "absence_ids"} {
        return [lsort $absence_ids]
    }
}

ad_proc -public im_absence_wf_exists_p {
    {-absence_type_id:required}
} {
    # Check if a workflow exists for this type
} {
    return [util_memoize [list im_absence_wf_exists_p_helper -absence_type_id $absence_type_id] 120]
}

ad_proc -public im_absence_wf_exists_p_helper {
    {-absence_type_id:required}
} {
    # Check if a workflow exists for this type
} {
    set wf_key [db_string wf "select trim(aux_string1) from im_categories where category_id = :absence_type_id" -default ""]
    set wf_exists_p [db_string wf_exists "select count(*) from wf_workflows where workflow_key = :wf_key"]
    return $wf_exists_p
}


ad_proc -public im_absence_calculate_absence_days {
    {-owner_id ""}
    {-group_ids ""}
    {-start_date ""}
    {-end_date ""}
    {-ignore_absence_ids ""}
    {-absence_id ""}
    {-exclude_week_days {0 6}}
    {-type "duration"}
    {-absence_type_id ""}
    {-substract_absence_type_ids ""}
} {
    Calculate the needed dates for an absence
    @param owner_id Owner for whom we calculate the actual absence
    @param group_ids Alternatively calculate for this group_ids. If neither group_ids nor owner_id is provided return absences for any group
    @param start_date Start of the absence
    @param end_date End of the absence
    @param ignore_absence_ids Ignore these absence_ids when calculating the dates. 
    @param absence_id In case we only want to look at one absence_id, then we need to make sure to calculate the duration correctly. It will be appended to the ignore_absence_ids for calculation
    @param type duration will return the sum of the days needed, dates will return the actual dates
} {
       
    set absence_status_id ""
    
    # does the absence exist?
    if {![db_string absence_exists_p "select 1 from im_user_absences where absence_id = :absence_id" -default 0]} {
        set absence_id ""
    }
    
    
    # Check if we calculate the days for an existing absence
    if {$absence_id ne ""} {
        lappend ignore_absence_ids $absence_id
        db_1row absence_data "select absence_type_id, absence_status_id, owner_id, group_id from im_user_absences where absence_id = :absence_id"
        
        # If we have an owner_id limit the absences to only this owner and the group the owner belongs to
        if {$owner_id ne ""} {
            # Get the groups the owner belongs to
            set group_ids [im_biz_object_memberships -member_id $owner_id]

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
        
        # Check if we have a workflow
        set wf_exists_p [im_absence_wf_exists_p -absence_type_id $absence_type_id]
        if {!$wf_exists_p} {
            set absence_status_sql "and absence_status_id not in ([template::util::tcl_to_sql_list [im_sub_categories [im_user_absence_status_active]]])"
        } else {
            set absence_status_sql "and absence_status_id != [im_user_absence_status_deleted]"
        } 
        
        # Additionally ignore any absence which has an older creation date and is of the same type.
        db_foreach ignoreable_absences "select object_id from acs_objects o, im_user_absences ua
            where o.object_id = ua.absence_id
            and ua.absence_type_id = :absence_type_id
            and ua.absence_status_id = :absence_status_id
            and o.creation_date > (select creation_date from acs_objects where object_id = :absence_id)
            and absence_id not in ([template::util::tcl_to_sql_list $ignore_absence_ids])
            $absence_status_sql
            $owner_sql
        " {
            lappend ignore_absence_ids $object_id
        }
                
        db_1row absence "select owner_id, duration_days from im_user_absences where absence_id = :absence_id"
        if {$end_date eq "" && $start_date eq ""} {
            db_1row absence "select start_date, end_date from im_user_absences where absence_id = :absence_id"
        }
    }
    
    # Get a list of dates in the range
    set dates_in_range [im_absence_week_days -week_day_list [list 0 1 2 3 4 5 6] -start_date $start_date -end_date $end_date]

    # Get the list of dates which are excluded
    if {$exclude_week_days eq ""} {
        set off_dates [list]
    } else {
        set off_dates [im_absence_week_days -week_day_list $exclude_week_days -start_date $start_date -end_date $end_date]
    }

    # If we have an ignore_absence_type_id then ignore the type
    if {$absence_type_id eq ""} {
        set absence_type_ids ""
    } else {
        set absence_type_ids [db_list higher_prio "select category_id from im_categories where category_type = 'Intranet Absence Type' and sort_order > (select sort_order from im_categories where category_id = :absence_type_id)"]
        lappend absence_type_ids $absence_type_id
    }
    
    
    # Get the existing absence dates in the interval for any higher category
    set existing_absence_dates [im_absence_dates -owner_id $owner_id -group_ids $group_ids -start_date $start_date -end_date $end_date -ignore_absence_ids $ignore_absence_ids -exclude_week_days $exclude_week_days -absence_type_ids $absence_type_ids -absence_status_id [im_user_absence_status_active]]

    # Join the dates together
    set existing_absence_dates [concat $existing_absence_dates $off_dates]

    # If this is a requested absence, append the requested days as existing absences as well
    if {[lsearch $absence_status_id [im_sub_categories [im_user_absence_status_requested]]]>-1} {
        set requested_absence_dates [im_absence_dates -owner_id $owner_id -group_ids $group_ids -start_date $start_date -end_date $end_date -ignore_absence_ids $ignore_absence_ids -exclude_week_days $exclude_week_days -absence_type_ids $absence_type_ids -absence_status_id [im_user_absence_status_requested]]
        set existing_absence_dates [concat $existing_absence_dates $requested_absence_dates]        
    }
    
    # Now check for each date in the range whether we need to take vacation then
    set required_dates [list]
    foreach date $dates_in_range {
        if {[lsearch $existing_absence_dates $date]<0} {
            lappend required_dates $date
        }
    }
    
    # Update the duration in the database for compatability reasons
    set new_duration [llength $required_dates]
    if {$absence_id ne ""} {
        # Check if duration changed
        if {[expr $new_duration - $duration_days] != 0} {
            # Update the duration in the database
            db_dml update_duration "update im_user_absences set duration_days = :new_duration where absence_id = :absence_id"
        }
    }
    
    if {$type == "duration"} {
        return [llength $required_dates]
    } else {
        return [lsort $required_dates]
    }
}

ad_proc -public im_absence_update_duration_days {
    {-interval "2 months"}
} {
    set absence_ids [db_list absences "select absence_id from im_user_absences,acs_objects where absence_id = object_id and creation_date > now() - interval :interval"]
    foreach absence_id $absence_ids {
        set duration_days [im_absence_calculate_absence_days -absence_id $absence_id]
        ns_log Notice "Updateing Absence $absence_id to $duration_days"
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

ad_proc -public im_absence_types {} {
    @author Neophytos Demetriou (neophytos@azet.sk)
} {
    set color_list [im_absence_cube_color_list]
    set sql "
        select category_id, category, enabled_p, aux_string2
        from im_categories
        where category_type = 'Intranet Absence Type'
        order by category_id
    "
    set result [list]
    set index -1
    db_foreach absence_category $sql {
        if { $aux_string2 eq {} } {
            set bg_color [lindex $color_list $index]
            incr index
        } else {
            set bg_color $aux_string2
        }
        set fg_color [im_absence_fg_color $bg_color]
        lappend result [list $category_id $category $enabled_p $bg_color $fg_color]
    }
    return $result
}


ad_proc -public im_absence_cube_legend {} {
    @author Neophytos Demetriou (neophytos@azet.sk)
} {

    append admin_html "<div class=filter-title>[lang::message::lookup "" intranet-timesheet2.Color_codes "Color Codes"]</div>\n"
    append admin_html "<table cellpadding='5' cellspacing='5'>\n"

    # Marc Fleischer: A question of color
    set index -1
    set categories [im_absence_types]
    foreach category_item $categories {
        foreach {category_id category enabled_p bg_color fg_color} $category_item break

        if { "t" == $enabled_p } {
            regsub -all " " $category "_" category_key
            set category_l10n [lang::message::lookup "" intranet-core.$category_key $category]
            append admin_html "<tr>[im_absence_render_cell $bg_color $fg_color $category_l10n left]</tr>\n"
       }
    }

    append admin_html "</table>\n"
}


ad_proc wf_trace_column_change__begin {
    {-trace_array:required ""}
    {-object_type_id:required ""}
    {-object_type:required ""}
    {-table:required ""}
    {-where_clause:required ""}
    {-column_array:required ""}
} {
    @author Neophytos Demetriou
} {
    upvar $trace_array wf_trace_cols
    upvar $column_array old

    set dynfields \
        [im_dynfield::dynfields \
            -object_type_id $object_type_id \
            -object_type $object_type]

    foreach attribute_id $dynfields {
         set column_name [im_dynfield::attribute::get_name_from_id -attribute_id $attribute_id]
         set pretty_name $column_name
         set proc_name ""
         if { [string match {*_id} $column_name] } {
             set proc_name "im_name_from_id"
         }
         set wf_trace_cols($column_name) [list $pretty_name $proc_name]
    }

    # start_date, 
    # end_date,
    # absence_type_id,
    # vacation_replacement_id,
    set where_clause [uplevel [list db_bind_var_substitution $where_clause]]
    set sql "
        select [join [array names wf_trace_cols] {,}]
        from im_user_absences 
        where ${where_clause}
    "
    db_1row old_data $sql -column_array old

}


ad_proc wf_trace_column_change__end {
    {-user_id:required ""}
    {-object_id:required ""}
    {-trace_array:required ""}
    {-table:required ""}
    {-where_clause:required ""}
    {-column_array:required ""}
    {-what "record"}
} {
    @author Neophytos Demetriou
} {
    upvar $trace_array wf_trace_cols
    upvar $column_array old

    # start_date, 
    # end_date,
    # absence_type_id,
    # vacation_replacement_id,
    set where_clause [uplevel [list db_bind_var_substitution $where_clause]]
    set sql "
        select [join [array names wf_trace_cols] {,}]
        from im_user_absences 
        where ${where_clause}
    "
    db_1row old_data $sql -column_array new

    set message ""
    foreach {column_name column_def} [array get wf_trace_cols] {
        foreach {pretty_name proc_name} $column_def break

        if { $old($column_name) ne $new($column_name) } {
            
            if { $proc_name ne {} } {
                append message "$pretty_name changed from [$proc_name $old($column_name)] to [$proc_name $new($column_name)]"
            } else {
                append message "$pretty_name changed from $old($column_name) to $new($column_name)"
            }

            callback im_trace_column_change \
                -user_id $user_id \
                -object_id $object_id \
                -table $table \
                -column_name $column_name \
                -pretty_name $pretty_name \
                -old_value $old($column_name) \
                -new_value $new($column_name)

        }

    }

    if {$message ne {}} {
        set message "[im_name_from_user_id $user_id] modified the ${what}. ${message}"
        callback im_trace_table_change \
            -object_id $object_id \
            -table $table \
            -message $message
    }

}

ad_proc -callback im_trace_table_change -impl im_trace_absence_change {
    -object_id
    -table
    -message 
} {
    @author Neophytos Demetriou (neophytos@azet.sk)
} {

    if {$table ne {im_user_absences}} {
        return
    }

    set action "modify absence"
    set action_pretty "Modify Absence"

    set case_id [db_string get_case "select min(case_id) from wf_cases where object_id = :object_id"]

    im_workflow_new_journal \
        -case_id $case_id \
        -action $action \
        -action_pretty $action_pretty \
        -message $message
}


