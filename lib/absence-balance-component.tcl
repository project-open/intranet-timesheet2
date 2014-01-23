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
ds_comment "[_ intranet-timesheet2.user_id_user_id]"

set current_year [db_string current_year "select to_char(now(), 'YYYY')"]

# Ignore the balance for bank holidays

set bank_holiday_category_ids [db_list bank_holidays "select child_id from im_category_hierarchy where parent_id = '5005'"]
lappend bank_holiday_category_ids 5005


if {[db_table_exists im_user_leave_entitlements]} {
set vacation_sql "
	select
                coalesce((select sum(a.duration_days) as absence_days from im_user_absences a where absence_type_id = category_id and owner_id = :user_id),0) as absence_days,
                coalesce((select sum(a.duration_days) as absence_days from im_user_absences a where absence_type_id = category_id and owner_id = :user_id and absence_status_id = 16000),0) as approved_absence_days,
                coalesce((select sum(a.duration_days) as absence_days from im_user_absences a where absence_type_id = category_id and owner_id = :user_id and absence_status_id = 16004),0) as requested_days,
                category_id,
                coalesce((select sum(l.entitlement_days) as absence_days from im_user_leave_entitlements l where leave_entitlement_type_id = category_id and owner_id = :user_id),0) as entitlement_days
	from
		im_categories c
	where
                category_type = 'Intranet Absence Type' and category_id not in ([template::util::tcl_to_sql_list $bank_holiday_category_ids])
"
    db_multirow -extend { absence_type remaining_days } absence_balance absence_balance_sql $vacation_sql {
	set absence_type [im_category_from_id $category_id]
	
	# Check if we have a workflow and then only use the approved days
	set wf_key [db_string wf "select trim(aux_string1) from im_categories where category_id = :category_id" -default ""]
	set wf_exists_p [db_string wf_exists "select count(*) from wf_workflows where workflow_key = :wf_key"]
	if {$wf_exists_p} {
	    set remaining_days [expr $entitlement_days - $approved_absence_days]
	} else {
	    set remaining_days [expr $entitlement_days - $absence_days]
	    set requested_days 0
	}
    }

} else {
    db_1row user_info "select coalesce(vacation_balance,0) as vacation_balance,
                          coalesce(vacation_days_per_year,0) as vacation_days_per_year,
                          coalesce(overtime_balance,0) as overtime_balance,
                          coalesce(rwh_days_last_year,0) as rwh_days_last_year,
                          coalesce(rwh_days_per_year,0) as rwh_days_per_year
                      from im_employees where employee_id = :user_id"

    # we need to limit to the current year if leave_entitlements are
    # not active yet
    set current_year [db_string current_year "select to_char(now(), 'YYYY')"]
    
    set start_of_year "$current_year-01-01"
    set end_of_year "$current_year-12-31"

    set vacation_sql "
	select
                coalesce((select sum(a.duration_days) as absence_days from im_user_absences a where absence_type_id = category_id and owner_id = :user_id and a.start_date <= :end_of_year and a.end_date >= :start_of_year),0) as absence_days,
                coalesce((select sum(a.duration_days) as absence_days from im_user_absences a where absence_type_id = category_id and owner_id = :user_id and absence_status_id = 16000 and a.start_date <= :end_of_year and a.end_date >= :start_of_year),0) as approved_absence_days,
                coalesce((select sum(a.duration_days) as absence_days from im_user_absences a where absence_type_id = category_id and owner_id = :user_id and absence_status_id = 16004 and a.start_date <= :end_of_year and a.end_date >= :start_of_year),0) as requested_days,
                category_id
	from
		im_categories c
	where
                category_type = 'Intranet Absence Type' and category_id not in ([template::util::tcl_to_sql_list $bank_holiday_category_ids])
"
    db_multirow -extend { entitlement_days absence_type remaining_days } absence_balance absence_balance_sql $vacation_sql {
	set absence_type [im_category_from_id $category_id]
	switch $category_id {
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
	set wf_key [db_string wf "select trim(aux_string1) from im_categories where category_id = :category_id" -default ""]
	set wf_exists_p [db_string wf_exists "select count(*) from wf_workflows where workflow_key = :wf_key"]
	ds_comment "$category_id :: $entitlement_days :: $approved_absence_days"
	if {$wf_exists_p} {
	    set remaining_days [expr $entitlement_days - $approved_absence_days]
	} else {
	    set remaining_days [expr $entitlement_days - $absence_days]
	    set requested_days 0
	}
    }
}

