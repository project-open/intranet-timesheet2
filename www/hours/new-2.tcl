# /www/intranet/hours/new-2.tcl
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
    hours:array,html
    julian_date
    { return_url "" }
}

set user_id [ad_maybe_redirect_for_registration]
set user_name [db_string user_name "select first_names || ' ' || last_name from cc_users where user_id=:user_id" -default "User $user_id"]
set date_format "YYYY-MM-DD"
set currency [ad_parameter -package_id [im_package_cost_id] "DefaultCurrency" "" "EUR"]


# Please note "_" instead of "-". This is because we use
# underscores in the invoices and other costs. So the
# timesheet information gets sorted in the right order.
set timesheet_log_date_format "YYYY_MM_DD"


db_transaction {
    foreach name [array names hours] {
	if { ![regsub {\.hours$} $name "" on_what_id] } {
	    continue
	}
	set hours_worked $hours($name)
	if { [empty_string_p $hours_worked] } {
	    set hours_worked 0
	}
	if { [info exists hours(${on_what_id}.note)] } {
	    set note [string trim $hours(${on_what_id}.note)]
	} else {
	    set note ""
	}
	if { [info exists hours(${on_what_id}.billing_rate)] } {
	    # Explicitely stated billing rate
	    set billing_rate $hours(${on_what_id}.billing_rate)
	} else {
	    set billing_rate ""

	    # Get the billing rate from the HR module
	    if {[db_table_exists im_employees]} {
		db_1row houly_costs "
			select
				hourly_cost as billing_rate,
				currency
			from
				im_employees 
			where 
				employee_id = :user_id"
	    }
	
	    if {"" == $billing_rate} { set billing_rate 0 }
	}

	if { $hours_worked == 0 && [empty_string_p $note] } {
	    db_dml hours_delete "
		delete from im_hours
		where
			project_id = :on_what_id
			and user_id = :user_id
			and day = to_date(:julian_date, 'J')
	    "

	    if {[db_table_exists im_costs]} {
		db_dml costs_delete "
		delete from im_costs
		where
			cost_type_id = [im_cost_type_timesheet]
			and project_id = :on_what_id
			and effective_date = to_date(:julian_date, 'J')
			and cause_object_id = :user_id
	        "
	    }

	} else {

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
			hours = :hours_worked, note = :note,
			billing_rate = :billing_rate
		where 
			project_id = :on_what_id
			and user_id = :user_id
			and day = to_date(:julian_date, 'J')
	    "

	    if { [db_resultrows] == 0 } {
		db_dml hours_insert "
		insert into im_hours (
			user_id, project_id, day, 
			hours, billing_rate, note
		) values (
			:user_id, :on_what_id, to_date(:julian_date,'J'), 
			:hours_worked, :billing_rate, :note
		)"
	    }

	    set cost_id [db_string costs_id_exist "select cost_id from im_costs where cost_type_id = [im_cost_type_timesheet] and project_id = :on_what_id and effective_date = to_date(:julian_date, 'J') and cause_object_id = :user_id" -default 0]

	    set day [db_string day "select to_char(to_date(:julian_date, 'J'), :timesheet_log_date_format) from dual"]
	    set cost_name "$day $user_name"
	    if {!$cost_id} {
		set cost_id [im_cost::new -cost_name $cost_name -cost_type_id [im_cost_type_timesheet]]
	    }

	    set customer_id [db_string customer_id "select company_id from im_projects where project_id = :on_what_id" -default 0]

	    # Update costs table
	    if {[db_table_exists im_costs]} {
	    db_dml cost_update "
	        update  im_costs set
	                cost_name               = :cost_name,
	                project_id              = :on_what_id,
	                customer_id             = :customer_id,
	                effective_date          = to_date(:julian_date, 'J'),
	                amount                  = :billing_rate * cast(:hours_worked as numeric),
	                currency                = :currency,
			payment_days		= 0,
	                vat                     = 0,
	                tax                     = 0,
	                cause_object_id         = :user_id,
	                description             = :note
	        where
	                cost_id = :cost_id
	    "

	    }

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
