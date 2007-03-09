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
    hours:array
    notes:array,html
    julian_date
    { return_url "" }
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

set item_nrs [array names hours]
set im_costs_exists_p [db_table_exists im_costs]

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
		cost_id as hour_cost_id
	from
		im_hours
	where
		user_id = :user_id
		and day = to_date(:julian_date, 'J')
"
db_foreach hours $sql {

    ns_log Notice "new-2: pid=$hour_project_id => $hour_cost_id"
    set hours_exists_p($hour_project_id) 1

    if {"" != $hour_cost_id} {
        set hours_cost_id($hour_project_id) $hour_cost_id
    }
}


# ----------------------------------------------------------
# Update items
# ----------------------------------------------------------

foreach project_id $item_nrs {

    ns_log Notice "timesheet2-tasks/new-2: project_id=$project_id"

    # Extract the parameters from the arrays
    set hours_worked [string trim $hours($project_id)]
    set note [string trim $notes($project_id)]

    if {"" == $project_id || 0 == $project_id} {
	ad_return_complaint 1 "Internal Error:<br>
            There is an empty project_id for item \# $project_id"
	return
    }
    
    # Filter & trim parameters
    if { [empty_string_p $hours_worked] } {
	set hours_worked 0
    }
    set note [string trim $note]


    # Always delete the cost item (both delete, update and new)
    if {[info exists hours_cost_id($project_id)]} {

	ns_log Notice "new-2: Delete timesheet entry for project_id=$project_id"
	db_dml update_hours "
		update im_hours
		set cost_id = null
		where	project_id = :project_id
			and user_id = :user_id
			and day = to_date(:julian_date, 'J')
	"

	set cost_id $hours_cost_id($project_id)
	ns_log Notice "new-2: Delete cost item=$cost_id for project_id=$project_id"
	db_string del_ts_costs "select im_cost__delete(:cost_id)"

	#ToDo: !!! Update the project's accumulated TS cost cache

    }

    if {$hours_worked == 0 || "" == $hours_worked} {

	# Check the array before deleting - saves a lot of sql statements...
	if {[info exists hours_exists_p($project_id)]} {

	    ns_log Notice "new-2: Delete timesheet entry for project_id=$project_id"
	    db_dml hours_delete "
		delete	from im_hours
		where	project_id = :project_id
			and user_id = :user_id
			and day = to_date(:julian_date, 'J')
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
			and day = to_date(:julian_date, 'J')
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
			to_date(:julian_date,'J'), :hours_worked, 
			:billing_rate, :billing_currency, 
			:note
		)"
	}

	# Update the reported hours on the timesheet task
	db_dml update_timesheet_task ""

    }
    
    # Create the necessary cost items for the timesheet hours
    im_timesheet2_sync_timesheet_costs -project_id $project_id

    # Update the project's logged hours cache
    hours_sum $project_id
}



db_release_unused_handles

if { ![empty_string_p $return_url] } {
    ns_log Notice "ad_returnredirect $return_url"
    ad_returnredirect $return_url
} else {
    ns_log Notice "ad_returnredirect index?[export_url_vars julian_date]"
    ad_returnredirect index?[export_url_vars julian_date]
}
