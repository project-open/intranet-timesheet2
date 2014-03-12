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

set vacation_category_ids [im_sub_categories 5000]

set exclude_category_ids [db_list categories "
	select
                category_id
	from
		im_categories c
	where
                category_type = 'Intranet Absence Type' and category_id not in ([template::util::tcl_to_sql_list $vacation_category_ids])
"]


set absence_type_html ""
foreach category_id $vacation_category_ids {
    
    set entitlement_days [db_string entitlement_days "select sum(l.entitlement_days) as absence_days from im_user_leave_entitlements l where leave_entitlement_type_id = :category_id and owner_id = :user_id" -default 0]
	set absence_type [im_category_from_id $category_id]

	# Check if we have a workflow and then only use the approved days
	set wf_key [db_string wf "select trim(aux_string1) from im_categories where category_id = :category_id" -default ""]
	set wf_exists_p [db_string wf_exists "select count(*) from wf_workflows where workflow_key = :wf_key"]
    set off_dates [im_absence_dates -absence_status_id 16000 -absence_type_ids $exclude_category_ids -owner_id $user_id -type "dates"]
    set requested_dates [list]

	if {$wf_exists_p} {
        set absence_dates [im_absence_dates -absence_status_id 16000 -absence_type_ids $category_id -owner_id $user_id -type "dates"]
        set requested_dates [im_absence_dates -absence_status_id 16004 -absence_type_ids $category_id -owner_id $user_id -type "dates"]
	} else {
        set absence_dates [im_absence_dates -absence_type_ids $category_id -owner_id $user_id -type "dates"]
	}
    
    ds_comment "balance:: $off_dates"
    # Calculate the absence days
    set required_dates [list]
    foreach date $absence_dates {
        if {[lsearch $off_dates $date]<0} {
            lappend required_dates $date
        }
    }
    set absence_days [llength $required_dates]
    
    # Calculate the requested dates
    set required_dates [list]
    foreach date $requested_dates {
        if {[lsearch $off_dates $date]<0} {
            lappend required_dates $date
        }
    }
    set requested_days [llength $required_dates]
    
    set remaining_days [expr $entitlement_days - $absence_days]
    
    if {$remaining_days != 0 || $requested_days !=0} {
    append absence_type_html "    
    <tr>
      <td align='left' valign='top' class='attribute' width='20%'>$absence_type</td>
      <td align='left' valign='top' class='value'>$remaining_days</td>
      <td align='left' valign='top' class='value'>$requested_days</td>
    </tr>"}
}

