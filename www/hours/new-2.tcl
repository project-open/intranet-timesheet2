# /www/intranet-timesheet2/hours/new-2.tcl
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

ad_page_contract {
    Writes hours to db. <br>
    The page acutally works like a "synchronizer" that compares the 
    hours already in the DB with the hours entered, determines the
    necessary action (delete, update, insert) and executes that action.

    @param hours0 Hash array (project_id -> hours) with the hours
                  for the given day and user.
    @param julian_date Julian date of the first day in the hours array
                       With single-day logging, this is the day for logging.
                       With weekly logging, this is the start of the week (Sunday!)
    @param show_week_p Set to "1" if we are storing hours for an entire week,
                       "0" for logging hours on a single day.

    @author dvr@arsdigita.com
    @author mbryzek@arsdigita.com
    @author frank.bergmann@project-open.com
    @author klaus.hofeditz@project-open.com

} {
    hours0:array,optional
    hours1:array,optional
    hours2:array,optional
    hours3:array,optional
    hours4:array,optional
    hours5:array,optional
    hours6:array,optional
    notes0:array,optional
    notes1:array,optional
    notes2:array,optional
    notes3:array,optional
    notes4:array,optional
    notes5:array,optional
    notes6:array,optional
    internal_notes0:array,optional
    materials0:array,optional
    etc:array,optional
    julian_date:integer
    { return_url "" }
    { show_week_p 1}
    { user_id_from_search "" }
}

# ----------------------------------------------------------
# Security / setting user
# ----------------------------------------------------------

# switch on detailed SQL logging
set debug_sql_p [ns_logctl severity "Debug(sql)"]
ns_logctl severity "Debug(sql)" 1

set current_user_id [auth::require_login]
set add_hours_p [im_permission $current_user_id "add_hours"]
set add_hours_all_p [im_permission $current_user_id "add_hours_all"]

# ToDo: add_hours_direct_reports_p is not checked, is it possible to add hours to other users?
set add_hours_direct_reports_p [im_permission $current_user_id "add_hours_direct_reports"]

# Estimate to complete?
set show_etc_p [im_table_exists im_estimate_to_completes]

if {!$add_hours_p} {
    ad_return_complaint 1 [lang::message::lookup "" intranet-timesheet2.Not_allowed_to_log_hours "You are not allowed to log hours."]
    ad_script_abort
}


# Is the user allowed to log hours for another user?
if {"" == $user_id_from_search } { 
    if {!$add_hours_all_p} {
	if {[im_permission $current_user_id "add_hours_all"]} {
	    set reportees [im_user_direct_reports_ids -user_id $current_user_id]
	} else {
	    # The user has no permission
	    set user_id_from_search $current_user_id 
	}
    }
}

# ----------------------------------------------------------
# Default
# ----------------------------------------------------------

set date_format "YYYY-MM-DD"
set default_currency [im_parameter -package_id [im_package_cost_id] "DefaultCurrency" "" "EUR"]
set wf_installed_p [util_memoize [list db_string timesheet_wf "select count(*) from apm_enabled_package_versions where package_key = 'intranet-timesheet2-workflow'"]]
set materials_p [parameter::get_from_package_key -package_key intranet-timesheet2 -parameter HourLoggingWithMaterialsP -default 0]
set material_name ""
set material_id ""

# should we limit the max number of hours logged per day?
set max_hours_per_day [parameter::get_from_package_key -package_key intranet-timesheet2 -parameter TimesheetMaxHoursPerDay -default 999]

# Conversion factor to calculate days from hours. Make sure it's a float number.
set hours_per_day [parameter::get_from_package_key -package_key intranet-timesheet2 -parameter TimesheetHoursPerDay -default 10]
set hours_per_day [expr $hours_per_day * 1.0]

# Other
set limit_to_one_day_per_main_project_p [parameter::get_from_package_key -package_key intranet-timesheet2 -parameter TimesheetLimitToOneDayPerUserAndMainProjectP -default 1]
set sync_cost_item_immediately_p [parameter::get_from_package_key -package_key intranet-timesheet2 -parameter "SyncHoursImmediatelyAfterEntryP" -default 1]
set check_all_hours_with_comment [parameter::get_from_package_key -package_key intranet-timesheet2 -parameter "ForceAllTimesheetEntriesWithCommentP" -default 1]

# Accept some cache inconsistencies? Experimental!
set performance_mode_p [parameter::get_from_package_key -package_key acs-kernel -parameter "PerformanceModeP" -default 0]


# ----------------------------------------------------------
# Simple 'Callback' for custom validation 
# ----------------------------------------------------------

# Callback placed after defaults to allow that variables get overwritten under certain 
# conditions by custom procedure using 'upvar'. 
# 
# Example: 
# $max_hours_per_day might be ignored under certain conditions. In this case 
# Custom validation function can overwrite the existing parameter  and set 
# variable max_hours_per_day used in script to '999'.      
set cust_validation_function [parameter::get -package_id [apm_package_id_from_key intranet-timesheet2] -parameter "CustomHoursEntryValidationFunction" -default ""]
if { "" != $cust_validation_function } {
		eval $cust_validation_function \
    			{[array get hours0]} \
			{[array get hours1]} \
			{[array get hours2]} \
			{[array get hours3]} \
			{[array get hours4]} \
			{[array get hours5]} \
			{[array get hours6]} \
			{[array get notes0]} \
			{[array get internal_notes0]} \
			{[array get materials0]} \
			$julian_date \
			$return_url \
			$show_week_p \
			$user_id_from_search \
			$max_hours_per_day
}	

if {![im_column_exists im_hours internal_note]} {
    ad_return_complaint 1 "Internal error in intranet-timesheet2:<br>
	The field im_hours.internal_note is missing.<br>
	Please notify your system administrator to upgrade
	your system to the latest version.<br>
    "
    ad_script_abort
}

# ----------------------------------------------------------
# Check that the comment has been specified for all hours
# if necessary
# ----------------------------------------------------------

if {!$show_week_p && $check_all_hours_with_comment} {
    foreach key [array names hours0] {
	set h $hours0($key)
	set c $notes0($key)
	if {"" == $h} { continue }

	if {"" == $c} {
	    ad_return_complaint 1 "
		<b>[lang::message::lookup "" intranet-timesheet2.You_have_to_provide_a_comment_for_every_entry "
			You have to provide a comment for every timesheet entry
		"]</b>:
	    "
	    ad_script_abort
	}
    }
}

# ----------------------------------------------------------
# Billing Rate & Currency
# ----------------------------------------------------------

set billing_rate 0
set billing_currency ""

db_0or1row get_billing_rate "
	select	hourly_cost as billing_rate,
		currency as billing_currency
	from	im_employees
	where	employee_id = :user_id_from_search
"

if {"" == $billing_currency} { set billing_currency $default_currency }


# ----------------------------------------------------------
# Start with synchronization
# ----------------------------------------------------------

# Add 0 to the days for logging, as this is used for single-day entry
set weekly_logging_days [parameter::get_from_package_key -package_key intranet-timesheet2 -parameter TimesheetWeeklyLoggingDays -default "0 1 2 3 4 5 6"]
# Add a "0" to refer to the current day for single-day logging.
set weekly_logging_days [set_union $weekly_logging_days [list 0]]
# Logging hours for a single day?
if {!$show_week_p} { set weekly_logging_days [list 0]}


# Go through all days of the week (or just a single one in case of single-day logging
set i 0 
foreach j $weekly_logging_days {
    set day_julian [expr $julian_date + $i]
    array unset database_hours_hash
    array unset database_notes_hash
    array unset database_internal_notes_hash
    array unset database_materials_hash
    array unset hours_cost_id
    array unset action_hash

    set material_sql "
			,h.material_id,
			(select material_name from im_materials m where m.material_id = h.material_id) as material_name
    "
    if {!$materials_p} { set material_sql "" }


    # ----------------------------------------------------------
    # Get the list of the hours of the current user today,
    # together with the main project (needed for ConfirmationObject).
    set database_hours_logged_sql "
		select	
			h.*,
			p.project_id as hour_project_id,
			h.cost_id as hour_cost_id
		from
			im_hours h,
			im_projects p
		where
			h.user_id = :user_id_from_search and
			h.day = to_date(:day_julian, 'J') and
			h.project_id = p.project_id
    "
    db_foreach database_hours $database_hours_logged_sql {
        set key "$hour_project_id"
	if {"" == $hours} { set hours 0 }

	# Store logged hours into Hash arrays.
    	set database_hours_hash($key) $hours
    	set database_notes_hash($key) $note
    	set database_internal_notes_hash($key) [value_if_exists internal_note]
    	set database_materials_hash($key) $material_name

	# Setup (project x day) => cost_id relationship
	if {"" != $hour_cost_id} {
	    set hours_cost_id($key) $hour_cost_id
	}
    }
    
    # ----------------------------------------------------------
    # Extract the information from "screen" into hash array with
    # same structure as the one from the database
   
    array unset screen_hours_hash
    set screen_hours_elements [array get hours$i]
    array set screen_hours_hash $screen_hours_elements

    array unset screen_notes_hash
    set screen_notes_elements [array get notes$i]
    array set screen_notes_hash $screen_notes_elements

    array unset screen_internal_notes_hash
    set screen_internal_notes_elements [array get internal_notes$i]
    array set screen_internal_notes_hash $screen_internal_notes_elements

    array unset screen_materials_hash
    set screen_materials_elements [array get materials$i]
    array set screen_materials_hash $screen_materials_elements

    # Check for HH:MI notation of hours and transform
    foreach key [array names screen_hours_hash] {
	set value [string trim $screen_hours_hash($key)]
	if {[regexp {([0-9]+)\:([0-9]+)} $value match hh mi] } {
	    set value [expr 1.0 * $hh + ($mi / 60.0)]
	    set screen_hours_hash($key) $value
	}
    }


    # Get the list of the union of key in both array
    set all_project_ids [set_union [array names screen_hours_hash] [array names database_hours_hash]]
    
    # Create the "action_hash" with a mapping (pid) => action for all lines where we
    # have to take an action. We construct this hash by iterating through all entries 
    # (both db and screen) and comparing their content.
    set total_screen_hours 0 
    foreach pid $all_project_ids {
	# Extract the hours and notes from the database hashes
	set db_hours ""
	set db_notes ""
	set db_internal_notes ""
	set db_materials ""
	if {[info exists database_hours_hash($pid)]} { set db_hours $database_hours_hash($pid) }
	if {[info exists database_notes_hash($pid)]} { set db_notes [string trim $database_notes_hash($pid)] }
	if {[info exists database_internal_notes_hash($pid)]} { set db_int_notes [string trim $database_internal_notes_hash($pid)] }
	if {[info exists database_materials_hash($pid)]} { set db_materials [string trim $database_materials_hash($pid)] }

	# Extract the hours and notes from the screen hashes
	set screen_hours ""
	set screen_notes ""
	set screen_internal_notes ""
	set screen_materials ""
	if {[info exists screen_hours_hash($pid)]} { set screen_hours [string trim $screen_hours_hash($pid)] }
	if {[info exists screen_notes_hash($pid)]} { set screen_notes [string trim $screen_notes_hash($pid)] }
	if {[info exists screen_internal_notes_hash($pid)]} { set screen_internal_notes [string trim $screen_internal_notes_hash($pid)] }
	if {[info exists screen_materials_hash($pid)]} { set screen_materials [string trim $screen_materials_hash($pid)] }

	if {"" != $screen_hours} {
	    if {![string is double $screen_hours] || $screen_hours < 0} {
		ad_return_complaint 1 "<b>[lang::message::lookup "" intranet-timesheet2.Only_positive_numbers_allowed "Only positive numbers allowed"]</b>:<br>
	         [lang::message::lookup "" intranet-timesheet2.Only_positive_numbers_allowed_help "
	   		The number '$screen_hours' contains invalid characters for a numeric value.<br>
			Please use the characters '0'-'9' and the '.' as a decimal separator. 
	         "]"
		ad_script_abort
	    }
	    set total_screen_hours [expr $total_screen_hours + $screen_hours]
	}

	# Determine the action to take on the database items from comparing database vs. screen
	set action error
	if {$db_hours eq "" && $screen_hours ne ""} { set action insert }
	if {$db_hours ne "" && $screen_hours eq ""} { set action delete }
	if {$db_hours ne "" && $screen_hours ne ""} { set action update }

	if {$db_hours == $screen_hours} { set action skip }

	# Deal with the case that the user has only changed the comment (in the single-day view)
	if {"skip" == $action && !$show_week_p && $db_notes != $screen_notes} { set action update }
	if {"skip" == $action && !$show_week_p && $db_internal_notes != $screen_internal_notes} { set action update }
	if {"skip" == $action && !$show_week_p && $db_materials != $screen_materials} { set action update }

	if {"skip" != $action} { set action_hash($pid) $action }
    }

    if {$total_screen_hours > $max_hours_per_day} {
	set day_ansi_err_msg [dt_julian_to_ansi $day_julian]
	ad_return_complaint 1 "<b>[lang::message::lookup "" intranet-timesheet2.Number_too_big_for_param "Number is larger than allowed"]</b>:<br>
            [lang::message::lookup "" intranet-timesheet2.Number_too_big_help "
                   On %day_ansi_err_msg% you have logged more hours than allowed (%total_screen_hours%).<br>
                   Please log no more than '%max_hours_per_day%' hours for one day.
	    "]"
            ad_script_abort
    }
    ns_log Notice "hours/new2: day=$i, database_hours_hash=[array get database_hours_hash]"
    ns_log Notice "hours/new2: day=$i, screen_hours_hash=[array get screen_hours_hash]"
    ns_log Notice "hours/new2: day=$i, action_hash=[array get action_hash]"


    # ----------------------------------------------------------
    # Custom validation of action_hash
    # Allows to veto entry of certain hours
    set cust_action_hash_function [parameter::get -package_id [apm_package_id_from_key intranet-timesheet2] -parameter "CustomHoursActionHashFunction" -default ""]
    if {"" ne $cust_action_hash_function} {
	if {[catch {
	    ns_log Notice "hours/new2: $cust_action_hash_function -user_id $user_id_from_search -julian_date $day_julian -action_hash_list [array get action_hash]"
	    set cust_action_hash_function_result [$cust_action_hash_function -user_id $user_id_from_search -julian_date $day_julian -action_hash_list [array get action_hash]]
	} err_msg]} {
	    ad_return_complaint 1 "<b>Error executing custom function</b>:<br>
            Function: <pre>$cust_action_hash_function -action_hash \[array get action_hash\]</pre><br>
            Error: <pre>$err_msg</pre><br>
            Stack: <pre>[ad_print_stack_trace]</pre>
            "
	    ad_script_abort
	}
    }

    # ad_return_complaint 1 "hours/new2: day=$i, action_hash=[array get action_hash]"
    # ad_script_abort


    # ----------------------------------------------------------
    # Execute the actions
    foreach project_id [array names action_hash] {
	if {$wf_installed_p} {

	# For all actions: We modify the hours that the person has logged that week, 
	# so we need to reset/delete the TimesheetConfObject.
	# ns_log Notice "hours/new-2: im_timesheet_conf_object_delete -project_id $project_id -user_id $user_id_from_search -day_julian $day_julian"
# !!!
#	    im_timesheet_conf_object_delete \
#		-project_id $project_id \
#		-user_id $user_id_from_search \
#		-day_julian $day_julian

	    set modified_julians [list]
	    if {[info exists modified_projects_hash($project_id)]} { set modified_julians $modified_projects_hash($project_id) }
	    lappend modified_julians $day_julian
	    set modified_projects_hash($project_id) $modified_julians
	}

	# Prepare hours_worked and hours_notes for insert & update actions
	set hours_worked 0
	if {[info exists screen_hours_hash($project_id)]} { set hours_worked $screen_hours_hash($project_id) }
	set note ""
	if {[info exists screen_notes_hash($project_id)]} { set note $screen_notes_hash($project_id) }
	set internal_note ""
	if {[info exists screen_internal_notes_hash($project_id)]} { set internal_note $screen_internal_notes_hash($project_id) }
	set material ""
	if {[info exists screen_materials_hash($project_id)]} { set material $screen_materials_hash($project_id) }

	if { [regexp {([0-9]+)(\,([0-9]+))?} $hours_worked] } {
	    regsub "," $hours_worked "." hours_worked
	    regsub "'" $hours_worked "." hours_worked
	} elseif { [regexp {([0-9]+)(\'([0-9]+))?} $hours_worked] } {
	    regsub "'" $hours_worked "." hours_worked
	    regsub "," $hours_worked "." hours_worked
	}

	# Calculate worked days based on worked hours
	set days_worked ""
	if {"" != $hours_worked} {
	    set days_worked [expr $hours_worked / $hours_per_day]
	}

	set action $action_hash($project_id)
	ns_log Notice "hours/new-2: action=$action, project_id=$project_id"
	switch $action {
	    insert {
		db_dml hours_insert "
		    insert into im_hours (
			user_id, project_id,
			day, hours, days,
			billing_rate, billing_currency,
			material_id,
			note,
			internal_note
		     ) values (
			:user_id_from_search, :project_id, 
			to_date(:day_julian,'J'), :hours_worked, :days_worked,
			:billing_rate, :billing_currency, 
			:material,
			:note,
			:internal_note
		     )"
	    }

	    delete {
		db_transaction {
		    # Delete any cost elements related to the project_id, user_id and day
		    ns_log Notice "hours/new-2: im_timesheet_costs_delete -project_id $project_id -user_id $user_id_from_search -day_julian $day_julian"
		    im_timesheet_costs_delete -project_id $project_id -user_id $user_id_from_search -day_julian $day_julian

		    db_dml hours_delete "
			delete	from im_hours
			where	project_id = :project_id
				and user_id = :user_id_from_search
				and day = to_date(:day_julian, 'J')
	            "
		}
	    }

	    update {
		db_transaction {
		    # Delete any cost elements related to the project_id, user_id and day
		    ns_log Notice "hours/new-2: im_timesheet_costs_delete -project_id $project_id -user_id $user_id_from_search -day_julian $day_julian"
		    im_timesheet_costs_delete -project_id $project_id -user_id $user_id_from_search -day_julian $day_julian

		    db_dml hours_update "
			update im_hours set 
				hours = :hours_worked, 
				days = :days_worked,
				note = :note,
				internal_note = :internal_note,
				cost_id = null,
				material_id = :material
			where
				project_id = :project_id
				and user_id = :user_id_from_search
				and day = to_date(:day_julian, 'J')
		        "
		}
	    }

	}
    }
    # end of looping through days


    if {$limit_to_one_day_per_main_project_p} {
	# Timesheet Correction Function:
	# Limit the number of days logged per project and day to 1.0
	# (the customer would be surprised to see one guy charging 
	# more then one day...
	# This query determines the logged hours per main project.
	set ts_correction_sql "
	select
		project_id as correction_project_id,
		sum(hours) as correction_hours
	from
		(select	h.hours,
			parent.project_id,
			parent.project_name,
			h.day::date,
			h.user_id
		from	im_projects parent,
			im_projects children,
			im_hours h
		where	
			parent.parent_id is null and
			h.user_id = :user_id_from_search and
			h.day::date = to_date(:day_julian,'J') and
			children.tree_sortkey between 
				parent.tree_sortkey and 
				tree_right(parent.tree_sortkey) and
			h.project_id = children.project_id
		) h
	group by project_id
	having sum(hours) > :hours_per_day
        "

	db_foreach ts_correction $ts_correction_sql {

	    # We have found a project with with more then $hours_per_day
	    # hours logged on it by a single user and a single days.
	    # We now need to cut all logged _days_ (not hours...) by
	    # the factor sum(hour)/$hours_per_day so that at the end we
	    # will get exactly one day logged to the main project.
	    set correction_factor [expr $hours_per_day / $correction_hours]

	    db_dml appy_correction_factor "
		update im_hours set days = days * :correction_factor
		where
			day = to_date(:day_julian,'J') and
			user_id = :user_id_from_search and
			project_id in (
				select	children.project_id
				from	im_projects parent,
					im_projects children
				where	parent.parent_id = :correction_project_id and
					children.tree_sortkey between 
						parent.tree_sortkey and 
						tree_right(parent.tree_sortkey)
			)
	    "

	}
    }

    incr i
}


# Save ETC Estmate To Complete
if {$show_etc_p} {
    # Delete all ETCs for this user. Audit remains...
    db_list del_etc "
	select	   im_estimate_to_complete__delete(etc_id)
	from	   im_estimate_to_completes te
	where	   te.etc_user_id = :current_user_id
    "

    foreach project_id [array names etc] {
	set etc_hours $etc($project_id)
	if {"" ne $etc_hours} {
	    set etc_id [db_string new_etc "select im_estimate_to_complete_new(:current_user_id, :project_id, :etc_hours)"]

	    # Write Audit Trail
	    im_audit -object_id $etc_id -action after_create
	}
    }
}



# ----------------------------------------------------------
# Notify supervisor about modified hours in the past
# ----------------------------------------------------------

if {$wf_installed_p && [array size modified_projects_hash] > 0} {
    set notify_supervisor_p [parameter::get_from_package_key -package_key intranet-timesheet2-workflow -parameter "NotifySupervisorDeleteConfObjectP" -default 0]
    if {$notify_supervisor_p} {
	set uid $user_id_from_search
	if {"" == $uid} { set uid $current_user_id }

	im_timesheet_conf_object_notify_supervisor \
	    -user_id $uid \
	    -modified_projects_tuples [array get modified_projects_hash]
    }
}


# ----------------------------------------------------------
# Calculate the transitive closure of super-projects for all
# modified projects and update hours for these projects.
# ----------------------------------------------------------

# ad_return_complaint 1 "perf=$performance_mode_p, action_hash=[array get action_hash]"

if {!$performance_mode_p} {
    # Safe and slow
    foreach pid $all_project_ids { set modified_projects_hash($pid) $pid }
} else {
    # Experimental - may lead to cache inconsistencies

    array set modified_projects_hash [array get action_hash]
    set new_parent_ids [array names modified_projects_hash]
    lappend new_parent_ids 0
    
    # ns_log Notice "new-2.tcl: new_parent_ids=$new_parent_ids"
    set new_parent_ids [db_list new_parents "
	select	distinct parent_id
	from	im_projects
	where	parent_id is not null and 
		project_id in ([join $new_parent_ids ","])
    "]
    set cnt 0
    while {[llength $new_parent_ids] > 0 && $cnt < 10} {
	foreach pid $new_parent_ids {
	    set modified_projects_hash($pid) $pid
	}
	set new_parent_ids [db_list new_parents "
		select	distinct parent_id
		from	im_projects
		where	parent_id is not null and 
			project_id in ([join $new_parent_ids ","])
        "]
	# ns_log Notice "new-2.tcl: new_parent_ids=$new_parent_ids"
	incr cnt
    }

}


# ad_return_complaint 1 "action_hash=[array get action_hash],<br>mod=[array get modified_projects_hash],<br>all=$all_project_ids"


# Create cost items for every logged hours?
# This may take up to a second per user, so we may want to avoid this
# in very busy Swisss systems where everybody logs hours between 16:00 and 16:30...
if {$sync_cost_item_immediately_p} {
    # Update the affected project's cost_hours_cache and cost_days_cache fields,
    # so that the numbers will appear correctly in the TaskListPage
    foreach project_id [array names modified_projects_hash] {
	# Update sum(hours) and percent_completed for all modified projects
	im_timesheet_update_timesheet_cache -project_id $project_id
	# Create timesheet cost_items for all modified projects
	im_timesheet2_sync_timesheet_costs -project_id $project_id
    }

    # Fraber 140103: !!!
    # The cost updates don't get promoted to the main project 
    im_cost_cache_sweeper
}



# Return to previous level of SQL debugging,
# at least when the page finishes without error...
ns_logctl severity "Debug(sql)" $debug_sql_p


# ----------------------------------------------------------
# Where to go from here?
# ----------------------------------------------------------

if { $return_url ne "" } {
    ad_returnredirect $return_url
} else {
    ad_returnredirect [export_vars -base index {julian_date}]
}
