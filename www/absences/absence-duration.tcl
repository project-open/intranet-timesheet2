# /packages/intranet-timesheet2/www/absences/absence-action.tcl
#
# Copyright (C) 2019 ]project-open[
#
# All rights reserved. Please check
# http://www.project-open.com/license/ for details.

ad_page_contract {
    Calculate the duration of an absence in days or hours,
    including public holidays for the specific user.
    
    @param start_date start of the absence, assuming 9:00
    @param end_date end of the absence, assuming 18:00
    @author frank.bergmann@project-open.com
} {
    start_date
    end_date
}

set current_user_id [auth::require_login]



set work_days_string [db_string days_in_period "select im_resource_mgmt_work_days(:current_user_id, :start_date::date, :end_date::date)"]
set work_days_array [lindex [split $work_days_string "="] 1]
regsub -all {,} $work_days_array " " work_days_array
set work_days_array [string range $work_days_array 1 end-1]
set work_days 0
foreach d $work_days_array { set work_days [expr $work_days + $d] }
set work_days [expr $work_days / 100.0]

set work_units_uom [parameter::get_from_package_key -package_key "intranet-timesheet2" -parameter "AbsenceDefaultDurationUnit" -default "days"]
switch $work_units_uom {
    "hours" {
	set work_units [expr 8.0 * $work_days]
	set work_units_uom_l10n [lang::message::lookup "" intranet-core.hours Hours]
    }
    "days" {
	set work_units $work_days
	set work_units_uom_l10n [lang::message::lookup "" intranet-core.days Days]
    }
    default {
	error "Invalid value for parameter AbsenceDefaultDurationUnit"
	set work_units "error"
    }
}

if {[regexp {^(.*)\.0$} $work_units match rounded_work_units]} {
    set work_units $rounded_work_units
}
# ad_return_complaint 1 $work_units


doc_return 200 "text/html" "$work_units $work_units_uom_l10n"
