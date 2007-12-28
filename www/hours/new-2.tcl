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
    Writes hours to db. 

    @param hours	
    @param julian_date

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

# Please note "_" instead of "-". This is because we use
# underscores in the invoices and other costs. So the
# timesheet information gets sorted in the right order.
set timesheet_log_date_format "YYYY_MM_DD"

set today [db_string day "
	select to_char(to_date(:julian_date, 'J'), :timesheet_log_date_format) 
	from dual
"]

# ----------------------------------------------------------
# Determine Billing Rate
# ----------------------------------------------------------

set billing_rate 0
set billing_currency ""

db_0or1row get_billing_rate "
	select
		hourly_cost as billing_rate,
		currency as billing_currency
	from
		im_employees
	where
		employee_id = :user_id
"

if {"" == $billing_currency} {
    set billing_currency [ad_parameter -package_id [im_package_cost_id] "DefaultCurrency" "" "EUR"]
}


# ----------------------------------------------------------
# Get the list of the hours of the current user today
# ----------------------------------------------------------

set sql "
	select
		project_id as hour_project_id,
		cost_id as hour_cost_id,
		to_char(day, 'J') as hour_julian_date
	from	im_hours
	where	user_id = :user_id
		and day = to_date(:julian_date, 'J')
"
db_foreach hours $sql {

    ns_log Notice "new-2: pid=$hour_project_id => $hour_cost_id"
    set hours_exists_p($hour_project_id-$hour_julian_date) 1

    if {"" != $hour_cost_id} {
        set hours_cost_id($hour_project_id-$hour_julian_date) $hour_cost_id
    }
}


# ----------------------------------------------------------
# Update items
# ----------------------------------------------------------

# Add 0 to the days for logging, as this is used for single-day
# entry
set weekly_logging_days [parameter::get_from_package_key -package_key intranet-timesheet2 -parameter TimesheetWeeklyLoggingDays -default "0 1 2 3 4 5 6"]
set weekly_logging_days [set_union $weekly_logging_days [list 0]]


foreach i $weekly_logging_days {

    # Check how many entries per column
    set item_nrs [array names hours$i]
    if {0 == [llength $item_nrs]} { continue }

    foreach project_id $item_nrs {
	
	ns_log Notice "timesheet2-tasks/new-2: project_id=$project_id"
	set hash_key "$project_id-[expr $julian_date+$i]"

	# Extract the hours worked from the array
	set hours_worked 0
	switch $i {
	    0 { if {[info exists hours0($project_id)]} { set hours_worked [string trim $hours0($project_id)] } }
	    1 { if {[info exists hours1($project_id)]} { set hours_worked [string trim $hours1($project_id)] } }
	    2 { if {[info exists hours2($project_id)]} { set hours_worked [string trim $hours2($project_id)] } }
	    3 { if {[info exists hours3($project_id)]} { set hours_worked [string trim $hours3($project_id)] } }
	    4 { if {[info exists hours4($project_id)]} { set hours_worked [string trim $hours4($project_id)] } }
	    5 { if {[info exists hours5($project_id)]} { set hours_worked [string trim $hours5($project_id)] } }
	    6 { if {[info exists hours6($project_id)]} { set hours_worked [string trim $hours6($project_id)] } }
	    default { ad_return_complaint 1 "hours/new-2: invalid day_of_week. Please inform SysAdmin."}
	}
	if { [empty_string_p $hours_worked] } { set hours_worked 0 }

	# A note is only available for single-day entry.
	# ToDo: Only enable for single-day entry
	set note 0
	if {[info exists notes0($project_id)]} { set note [string trim $notes0($project_id)] }
	set note [string trim $note]
	
	if {"" == $project_id || 0 == $project_id} {
	    ad_return_complaint 1 "Internal Error:<br>There is an empty project_id for item \# $project_id"
	    return
	}

	# Always delete the cost item (both delete, update and new)
	if {[info exists hours_cost_id($hash_key)]} {
	    ns_log Notice "new-2: Delete timesheet entry for project_id=$project_id"
	    db_dml update_hours "
		update im_hours
		set cost_id = null
		where	project_id = :project_id
			and user_id = :user_id
			and day = to_date([expr $julian_date+$i], 'J')
	    "

	    set cost_id $hours_cost_id($hash_key)
	    ns_log Notice "new-2: Delete cost item=$cost_id for project_id=$project_id and i=$i"
	    db_string del_ts_costs "select im_cost__delete(:cost_id)"
	    
	    # The project's timesheet cache is updated every X minutes by a sweeper..
	}

	if {$hours_worked == 0 || "" == $hours_worked} {

	    # Check the array before deleting - saves a lot of sql statements...
	    if {[info exists hours_exists_p($hash_key)]} {
		
		ns_log Notice "new-2: Delete timesheet entry for project_id=$project_id"
		db_dml hours_delete "
			delete	from im_hours
			where	project_id = :project_id
				and user_id = :user_id
				and day = to_date([expr $julian_date+$i], 'J')
	        "

		# Update the project's accummulated hours cache
		if { [db_resultrows] != 0 } {
		    db_dml update_timesheet_task {}
		}

	    }
	    
	} else {

	    ns_log Notice "timesheet2-tasks/new-2: Create"

	    # Replace "," by "."
	    if { [regexp {([0-9]+)(\,([0-9]+))?} $hours_worked] } {
		regsub "," $hours_worked "." hours_worked
		regsub "'" $hours_worked "." hours_worked
	    } elseif { [regexp {([0-9]+)(\'([0-9]+))?} $hours_worked] } {
		regsub "'" $hours_worked "." hours_worked
		regsub "," $hours_worked "." hours_worked
	    }
	    
	    # Update the hours table
	    #
	    db_dml hours_update "
		update im_hours
		set 
			hours = :hours_worked, 
			note = :note,
			cost_id = null
		where
			project_id = :project_id
			and user_id = :user_id
			and day = to_date([expr $julian_date+$i], 'J')
	    "

	    # Add a new im_hour record if there wasn't one before...
	    if { [db_resultrows] == 0 } {
		db_dml hours_insert "
		    insert into im_hours (
			user_id, project_id,
			day, hours, 
			billing_rate, billing_currency, 
			note
		     ) values (
			:user_id, :project_id, 
			to_date([expr $julian_date+$i],'J'), :hours_worked, 
			:billing_rate, :billing_currency, 
			:note
		     )"
	    }
	    
	    # Update the reported hours on the timesheet task
	    db_dml update_timesheet_task ""
	    
	}
    
	# Create the necessary cost items for the timesheet hours
	im_timesheet2_sync_timesheet_costs -project_id $project_id

	# End of foreach project_id
    }
  
    # end of foreach i clause
} 

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
