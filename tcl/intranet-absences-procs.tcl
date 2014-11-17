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

ad_proc -public im_absence_day_list {
    {-date_format:required}
    {-num_days:required}
    {-report_start_date:required}
} {
    get a day_list
} {
    return [util_memoize [list im_absence_day_list_helper -date_format $date_format -num_days $num_days -report_start_date $report_start_date]]
}

ad_proc -public im_absence_day_list_helper {
    {-date_format:required}
    {-num_days:required}
    {-report_start_date:required}
} {
    get a day_list
} {
        
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
        lappend day_list [list $date_date $date_day_of_month $date_month $date_year]
    }
    return $day_list
}


ad_proc -public im_absence_cube_component {
    -user_id_from_search:required
    {-num_days 21}
    {-absence_status_id "" }
    {-absence_type_id "" }
    {-user_selection "" }
    {-timescale "" }
    {-report_start_date "" }
    {-report_end_date "" }
    {-user_id ""}
    {-cost_center_id ""}
    {-hide_colors_p 0}
    {-project_id ""}
} {

    Makes use of im_absence_cube to return a rendered cube with 
    a graphical absence display for users.

    Copied and modified im_absence_vacation_balance_component to
	ensure that it parses the include in a similar manner.

} {

    # NOTE: We had to comment out the following even though it is 
    # part of im_absence_vacation_balance_component in order to
    # ensure that intranet-timesheet2/absences/index will continue
    # to work as it used to when it was using the im_absence_cube proc.
    #
    # Show only if user is an employee
    # if { ![im_user_is_employee_p $user_id_from_search] } { return "" }

    set current_user_id [ad_get_user_id]
    # This is a sensitive field, so only allows this for the user himself
    # and for users with HR permissions.

    set read_p 0
    if {$user_id_from_search == $current_user_id} { set read_p 1 }
    if {[im_permission $current_user_id view_hr]} { set read_p 1 }
    if {!$read_p} { return "" }

    set params [list \
		    [list user_id_from_search $user_id_from_search] \
			[list num_days $num_days] \
			[list absence_status_id $absence_status_id] \
			[list absence_type_id $absence_type_id] \
			[list user_selection $user_selection] \
			[list timescale $timescale] \
			[list report_start_date $report_start_date] \
			[list report_end_date $report_end_date] \
			[list user_id $user_id] \
			[list cost_center_id $cost_center_id] \
			[list hide_colors_p $hide_colors_p] \
			[list project_id $project_id] \
		    [list return_url [im_url_with_query]] \
    ]

    set result [ad_parse_template -params $params "/packages/intranet-timesheet2/lib/absence-cube"]
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
    ds_comment "Abensece:: $absence_status_id"
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
                
        db_1row absence "select owner_id,start_date,end_date, duration_days from im_user_absences where absence_id = :absence_id"
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
