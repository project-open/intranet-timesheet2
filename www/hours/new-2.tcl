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
    project_ids:array,integer
    timesheet_task_ids:array,integer
    hours:array
    notes:array,html
    julian_date
    { return_url "" }
}


# ----------------------------------------------------------
# Default & Security
# ----------------------------------------------------------

set user_id [ad_maybe_redirect_for_registration]
set user_name [db_string user_name "select first_names || ' ' || last_name from cc_users where user_id=:user_id" -default "User $user_id"]
set date_format "YYYY-MM-DD"

# Please note "_" instead of "-". This is because we use
# underscores in the invoices and other costs. So the
# timesheet information gets sorted in the right order.
set timesheet_log_date_format "YYYY_MM_DD"

set item_nrs [array names hours]
ns_log Notice "timesheet2-tasks/new-2: items_nrs=$item_nrs"



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
# Update items
# ----------------------------------------------------------

foreach item_nr $item_nrs {

    ns_log Notice "timesheet2-tasks/new-2: item_nr=$item_nr"

    # Extract the parameters from the arrays
    set hours_worked [string trim $hours($item_nr)]
    set project_id $project_ids($item_nr)
    set note [string trim $notes($item_nr)]
    set timesheet_task_id $timesheet_task_ids($item_nr)

    if {"" == $project_id || 0 == $project_id} {
	ad_return_complaint 1 "Internal Error:<br>
            There is an empty project_id for item \# $item_nr"
	return
    }
    
    # Filter & trim parameters
    if { [empty_string_p $hours_worked] } {
	set hours_worked 0
    }
    set note [string trim $note]
    
    if { $hours_worked == 0 } {

	# Delete a timesheet entry 
	ns_log Notice "timesheet2-tasks/new-2: Delete timesheet entry for task_id=$timesheet_task_id"
	db_dml hours_delete "
		delete from im_hours
		where
			project_id = :project_id
			and timesheet_task_id = :timesheet_task_id
			and user_id = :user_id
			and day = to_date(:julian_date, 'J')
	"

	ns_log Notice "timesheet2-tasks/new-2: Delete cost items of timesheet task"
	if { [db_resultrows] != 0 } {

	    db_exec_plsql delete_timesheet_costs {}
	    db_dml update_timesheet_task {}

	}


    } else {

	# Create or update a timesheet entry
	ns_log Notice "timesheet2-tasks/new-2: Create"
	if { [regexp {([0-9]+)(\,([0-9]+))?} $hours_worked] } {
	    regsub "," $hours_worked "." hours_worked
	    regsub "'" $hours_worked "." hours_worked
	} elseif { [regexp {([0-9]+)(\'([0-9]+))?} $hours_worked] } {
	    regsub "'" $hours_worked "." hours_worked
	    regsub "," $hours_worked "." hours_worked
	}

	# Check if this entry is coming from a project without a 
	# timesheet task already defined:
	if {"" == $timesheet_task_id || 0 == $timesheet_task_id} {
	    set timesheet_task_id [db_string existing_default_task "
		select	task_id
		from	im_timesheet_tasks_view
		where	project_id = :project_id
			and task_nr = 'default'
            " -default 0]
	}

	if {"" == $timesheet_task_id || 0 == $timesheet_task_id} {

	    # Create a default timesheet task for this project
	    set task_id [im_new_object_id]
	    set task_nr "default"
	    set task_name "Default Task"
	    set material_id [db_string default_material "select material_id from im_materials where material_nr='default'" -default 0]
	    if {!$material_id} { 
		ad_return_complaint 1 "Configuration Error:<br>Error during the creation of a default timesheet task for project \#$project_id: We couldn't find any default material with the material_nr 'default'. <br>Please inform your system administrator or contact Project/Open."
	    }
	    set cost_center_id ""
	    set uom_id [im_uom_hour]
	    set task_type_id [im_timesheet_task_type_standard]
	    set task_status_id [im_timesheet_task_status_active]
	    set description "Default task for timesheet logging convenience - please update"

	    db_exec_plsql task_insert ""
	    set timesheet_task_id $task_id
	}


	
	# Update the hours table
	#
	db_dml hours_update "
		update im_hours
		set 
			hours = :hours_worked, 
			note = :note
		where 
			project_id = :project_id
			and timesheet_task_id = :timesheet_task_id
			and user_id = :user_id
			and day = to_date(:julian_date, 'J')
	"

	# Add a new im_hour record if there wasn't one before...
	if { [db_resultrows] == 0 } {
	    db_dml hours_insert "
		insert into im_hours (
			user_id, project_id, timesheet_task_id,
			day, hours, 
			billing_rate, billing_currency, 
			note
		) values (
			:user_id, :project_id, :timesheet_task_id, 
			to_date(:julian_date,'J'), :hours_worked, 
			:billing_rate, :billing_currency, 
			:note
		)"
	}

	# Update the reported hours on the timesheet task
	db_dml update_timesheet_task ""


	ns_log Notice "timesheet2-tasks/new-2: Determine the cost-item related to task"
	set cost_id [db_string costs_id_exist "
		select
			min(cost_id)
		from 
			im_costs 
		where 
			cost_type_id = [im_cost_type_timesheet] 
			and project_id = :project_id
			and effective_date = to_date(:julian_date, 'J') 
			and cause_object_id = :timesheet_task_id
	" -default ""]

	set day [db_string day "select to_char(to_date(:julian_date, 'J'), :timesheet_log_date_format) from dual"]
	set cost_name "$day $user_name"
	if {"" == $cost_id} {
	    set cost_id [im_cost::new -cost_name $cost_name -cost_type_id [im_cost_type_timesheet]]
	}

	set customer_id [db_string customer_id "select company_id from im_projects where project_id = :project_id" -default 0]

	# Update costs table
	if {[db_table_exists im_costs]} {
	    db_dml cost_update "
	        update  im_costs set
	                cost_name               = :cost_name,
	                project_id              = :project_id,
	                customer_id             = :customer_id,
	                effective_date          = to_date(:julian_date, 'J'),
	                amount                  = :billing_rate * cast(:hours_worked as numeric),
	                currency                = :billing_currency,
			payment_days		= 0,
	                vat                     = 0,
	                tax                     = 0,
	                cause_object_id         = :timesheet_task_id,
	                description             = :note
	        where
	                cost_id = :cost_id
	    "

	}
    }

}


db_release_unused_handles

if { ![empty_string_p $return_url] } {
    ns_log Notice "ad_returnredirect $return_url"
    ad_returnredirect $return_url
} else {
    ns_log Notice "ad_returnredirect index?[export_url_vars julian_date]"
    ad_returnredirect index?[export_url_vars julian_date]
}
