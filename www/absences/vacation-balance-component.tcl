# /packages/intranet-timesheet2/www/absences/vacation-balance-component.tcl
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

# ---------------------------------------------------------------
# 1. Page Contract
# ---------------------------------------------------------------

#ad_page_contract {
#    Shows the vacation balance for the user and the current year.
#    @author Frank Bergmann (frank.bergmann@project-open.com)
#} {
#    user_id_from_search:integer
#}

# ---------------------------------------------------------------
# 2. Defaults & Security
# ---------------------------------------------------------------

set current_user_id [ad_maybe_redirect_for_registration]
set date_format "YYYY-MM-DD"
set package_key "intranet-timesheet2"
set view_absences_p [im_permission $current_user_id "view_absences"]
set view_absences_all_p [im_permission $current_user_id "view_absences_all"]
set add_absences_p [im_permission $current_user_id "add_absences"]
set today [db_string today "select now()::date"]

set page_title [lang::message::lookup "" intranet-timesheet2.Vacation_Balance "Vacation Balance"]
set absence_base_url "/intranet-timesheet2/absences"
set return_url [im_url_with_query]
set user_view_url "/intranet/users/view"


set current_year [db_string current_year "select to_char(now(), 'YYYY')"]

set start_of_year "$current_year-01-01"
set end_of_year "$current_year-12-31"


# ------------------------------------------------------------------
# User Info
# ------------------------------------------------------------------

db_0or1row user_info "
	select	u.user_id,
		e.*,
		im_name_from_user_id(u.user_id) as user_name
	from	users u
		LEFT OUTER JOIN im_employees e ON e.employee_id = u.user_id
	where	u.user_id = :user_id_from_search
"


# ------------------------------------------------------------------
# 
# ------------------------------------------------------------------

list::create \
    -name vacation_balance \
    -multirow vacation_balance_multirow \
    -key absence_id \
    -checkbox_name checkbox \
    -selected_format "normal" \
    -class "list" \
    -main_class "list" \
    -sub_class "narrow" \
    -actions {
    } -elements {
        absence_name {
            label "[lang::message::lookup {} intranet-timesheet2.Name Name]"
            link_url_eval $absence_url
        }
	absence_type {
            label "[lang::message::lookup {} intranet-timesheet2.Type Type]"
	}
	start_date_pretty {
            label "[lang::message::lookup {} intranet-timesheet2.Start_Date Start]"
	}
	end_date_pretty {
            label "[lang::message::lookup {} intranet-timesheet2.End_Date End]"
	}
	duration_days {
            label "[lang::message::lookup {} intranet-timesheet2.Vacation_Days_Taken {Vacation Days Taken}]"
	}
    }

set vacation_sql "
	select
		a.*,
		substring(a.description from 1 for 40) as description_pretty,
		substring(a.contact_info from 1 for 40) as contact_info_pretty,
		to_char(a.start_date, :date_format) as start_date_pretty,
		to_char(a.end_date, :date_format) as end_date_pretty,
		im_name_from_user_id(a.owner_id) as owner_name
	from
		im_user_absences a
	where
		a.owner_id = :user_id_from_search and
		a.start_date <= :end_of_year and
		a.end_date >= :start_of_year and 
		a.absence_type_id = 5000 and 
		a.absence_status_id <> 16006 and 
		a.absence_status_id <> 16002
	order by
		a.start_date
"
if {![info exists vacation_balance] || "" == $vacation_balance} { set vacation_balance 0 }
if {"" == $vacation_days_per_year} { set vacation_days_per_year 0 }

set vacation_days_left [expr $vacation_balance + $vacation_days_per_year]
set vacation_days_taken 0

db_multirow -extend { absence_url absence_type } vacation_balance_multirow vacation_balance $vacation_sql {
    set absence_url [export_vars -base "$absence_base_url/new" {{form_mode display} absence_id}]

    set absence_type [im_category_from_id $absence_type_id]

    switch $absence_type_id {
	5000 { 
	    # Vacation
	    set vacation_days_taken [expr $vacation_days_taken + $duration_days]
	    set vacation_days_left [expr $vacation_days_left - $duration_days] 
	}
	5001 { 
	    # Personal
	    set vacation_days_taken [expr $vacation_days_taken + $duration_days]
	    set vacation_days_left [expr $vacation_days_left - $duration_days] 
	}
	5002 {
	    # Sick Leave
	    # nothing
	}
	5003 {
	    # Travel
	    set duration_days 0
	}
	5004 {
	    # Training
	    set duration_days 0
	}
	5005 {
	    # Bank Holiday
	    set duration_days 0
	}
    }
}


# ------------------------------------------------------------------
# Calculate the number of vacation days
# ------------------------------------------------------------------

