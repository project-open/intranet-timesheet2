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
} {
    hours0:array,optional
    hours1:array,optional
    hours2:array,optional
    hours3:array,optional
    hours4:array,optional
    hours5:array,optional
    hours6:array,optional
    notes0:array,optional
    julian_date:integer
    { return_url "" }
    { show_week_p 1}
}

# ----------------------------------------------------------
# Default & Security
# ----------------------------------------------------------

set user_id [ad_maybe_redirect_for_registration]
set date_format "YYYY-MM-DD"
set default_currency [ad_parameter -package_id [im_package_cost_id] "DefaultCurrency" "" "EUR"]
set wf_installed_p [util_memoize "db_string timesheet_wf \"select count(*) from apm_packages where package_key = 'intranet-timesheet2-workflow'\""]


# ----------------------------------------------------------
# Billing Rate & Currency
# ----------------------------------------------------------

set billing_rate 0
set billing_currency ""

db_0or1row get_billing_rate "
	select	hourly_cost as billing_rate,
		currency as billing_currency
	from	im_employees
	where	employee_id = :user_id
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
foreach i $weekly_logging_days {

    set day_julian [expr $julian_date+$i]

    array unset database_hours_hash
    array unset database_notes_hash
    array unset hours_cost_id
    array unset action_hash

    # ----------------------------------------------------------
    # Get the list of the hours of the current user today,
    # together with the main project (needed for ConfirmationObject).
    set database_hours_logged_sql "
		select	
			p.project_id as hour_project_id,
			h.cost_id as hour_cost_id,
			h.hours,
			h.note
		from
			im_hours h,
			im_projects p
		where
			h.user_id = :user_id and
			h.day = to_date(:day_julian, 'J') and
			h.project_id = p.project_id
    "
    db_foreach hours $database_hours_logged_sql {

        set key "$hour_project_id"
	if {"" == $hours} { set hours 0 }

	# Store logged hours into Hash arrays.
    	set database_hours_hash($key) $hours
    	set database_notes_hash($key) $note
	ns_log Notice "hours/new2: database_hours_hash($key) = '$hours'"

	# Setup (project x day) => cost_id relationship
	if {"" != $hour_cost_id} {
	    set hours_cost_id($key) $hour_cost_id
	}
    }
    
    # ----------------------------------------------------------
    # Extract the information from "screen" into hash array with
    # same structure as the one from the database

    set screen_hours_elements [array get hours$i]
    array set screen_hours_hash $screen_hours_elements

    set screen_notes_elements [array get notes$i]
    array set screen_notes_hash $screen_notes_elements


    ns_log Notice "hours/new2: hours:'[array get database_hours_hash]'"
    ns_log Notice "hours/new2: screen:'[array get screen_hours_hash]'"

    # Get the list of the union of key in both array
    set all_project_ids [set_union [array names screen_hours_hash] [array names database_hours_hash]]
    
    # Create the "action_hash" with a mapping (pid) => action for all lines where we
    # have to take an action. We construct this hash by iterating through all entries 
    # (both db and screen) and comparing their content.
    foreach pid $all_project_ids {
	# Extract the hours and notes from the database hashes
	set db_hours ""
	set db_notes ""
	if {[info exists database_hours_hash($pid)]} { set db_hours $database_hours_hash($pid) }
	if {[info exists database_notes_hash($pid)]} { set db_notes [string trim $database_notes_hash($pid)] }

	# Extract the hours and notes from the screen hashes
	set screen_hours ""
	set screen_notes ""
	if {[info exists screen_hours_hash($pid)]} { set screen_hours $screen_hours_hash($pid) }
	if {[info exists screen_notes_hash($pid)]} { set screen_notes [string trim $screen_notes_hash($pid)] }

	if {"" != $screen_hours} {
	    if {![string is double $screen_hours] || $screen_hours < 0} {
		ad_return_complaint 1 "<b>[lang::message::lookup "" intranet-timesheet2.Only_positive_numbers_allowed "Only positive numbers allowed"]</b>:<br>
	         [lang::message::lookup "" intranet-timesheet2.Only_positive_numbers_allowed_help "
	   		The number '$screen_hours' contains invalid characters for a numeric value.<br>
			Please use the characters '0'-'9' and the '.' as a decimal separator. 
	         "]"
		ad_script_abort
	    }
	}

	# Determine the action to take on the database items from comparing database vs. screen
	set action error
	if {$db_hours == "" && $screen_hours != ""} { set action insert }
	if {$db_hours != "" && $screen_hours == ""} { set action delete }
	if {$db_hours != "" && $screen_hours != ""} { set action update }
	if {$db_hours == $screen_hours} { set action skip }

	# Deal with the case that the user has only changed the comment.
	if {"skip" == $action && $db_notes != $screen_notes} { set action update }

	ns_log Notice "hours/new-2: pid=$pid, day=$day_julian, db:'$db_hours', screen:'$screen_hours' => action=$action"

	if {"skip" != $action} { set action_hash($pid) $action }
    }

    ns_log Notice "hours/new-2: array='[array get action_hash]'"

    # Execute the actions
    foreach project_id [array names action_hash] {

	ns_log Notice "hours/new-2: project_id=$project_id"

	# For all actions: We modify the hours that the person has logged that week, 
	# so we need to reset/delete the TimesheetConfObject.
	ns_log Notice "hours/new-2: im_timesheet_conf_object_delete -project_id $project_id -user_id $user_id -day_julian $day_julian"

	if {$wf_installed_p} {
	    im_timesheet_conf_object_delete \
		-project_id $project_id \
		-user_id $user_id \
		-day_julian $day_julian
	}

	# Delete any cost elements related to the hour.
	# This time project_id refers to the specific (sub-) project.
	ns_log Notice "hours/new-2: im_timesheet_costs_delete -project_id $project_id -user_id $user_id -day_julian $day_julian"
	im_timesheet_costs_delete \
	    -project_id $project_id \
	    -user_id $user_id \
	    -day_julian $day_julian


	# Prepare hours_worked and hours_notes for insert & update actions
	set hours_worked 0
	if {[info exists screen_hours_hash($project_id)]} { set hours_worked $screen_hours_hash($project_id) }
	set note ""
	if {[info exists screen_notes_hash($project_id)]} { set note $screen_notes_hash($project_id) }

	if { [regexp {([0-9]+)(\,([0-9]+))?} $hours_worked] } {
	    regsub "," $hours_worked "." hours_worked
	    regsub "'" $hours_worked "." hours_worked
	} elseif { [regexp {([0-9]+)(\'([0-9]+))?} $hours_worked] } {
	    regsub "'" $hours_worked "." hours_worked
	    regsub "," $hours_worked "." hours_worked
	}

	set action $action_hash($project_id)
	ns_log Notice "hours/new-2: action=$action, project_id=$project_id"
	switch $action {

	    insert {
		db_dml hours_insert "
		    insert into im_hours (
			user_id, project_id,
			day, hours, 
			billing_rate, billing_currency, 
			note
		     ) values (
			:user_id, :project_id, 
			to_date(:day_julian,'J'), :hours_worked, 
			:billing_rate, :billing_currency, 
			:note
		     )"
	    
		# Update the reported hours on the timesheet task
		db_dml update_timesheet_task ""
		# ToDo: Propagate change through hierarchy?

	    }

	    delete {
		db_dml hours_delete "
			delete	from im_hours
			where	project_id = :project_id
				and user_id = :user_id
				and day = to_date(:day_julian, 'J')
	        "

		# Update the project's accummulated hours cache
		if { [db_resultrows] != 0 } {
		    db_dml update_timesheet_task {}
		}
	    }

	    update {
		db_dml hours_update "
		update im_hours
		set 
			hours = :hours_worked, 
			note = :note,
			cost_id = null
		where
			project_id = :project_id
			and user_id = :user_id
			and day = to_date(:day_julian, 'J')
	        "
	    }

	}
    }
    # end of looping through days

}


# Create the necessary cost items for the timesheet hours
# im_timesheet2_sync_timesheet_costs -project_id $project_id


# ----------------------------------------------------------
# Where to go from here?
# ----------------------------------------------------------

if { ![empty_string_p $return_url] } {
    ns_log Notice "ad_returnredirect $return_url"
    ad_returnredirect $return_url
} else {
    ns_log Notice "ad_returnredirect index?[export_url_vars julian_date]"
    ad_returnredirect index?[export_url_vars julian_date]
}
