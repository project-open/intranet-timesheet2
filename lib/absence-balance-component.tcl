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

set current_year [dt_systime -format "%Y"]

# Limit to view only for one year
set eoy "${current_year}-12-31"
set soy "${current_year}-01-01"
set booking_date_sql "booking_date <= now() and to_date(:soy,'YYYY-MM-DD') <= booking_date"
    

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
    
    set entitlement_days [db_string entitlement_days "select coalesce(sum(l.entitlement_days),0) as absence_days from im_user_leave_entitlements l where leave_entitlement_type_id = :category_id and owner_id = :user_id and to_char(booking_date,'YYYY') <= to_char(now(),'YYYY')" -default 0]
	set absence_type [im_category_from_id $category_id]

	# Check if we have a workflow and then only use the approved days
	set wf_key [db_string wf "select trim(aux_string1) from im_categories where category_id = :category_id" -default ""]
	set wf_exists_p [db_string wf_exists "select count(*) from wf_workflows where workflow_key = :wf_key"]

    if {$wf_exists_p} {
        set absence_days [db_string absence_days "select coalesce(sum(duration_days),0)
            from im_user_absences 
            where start_date::date <= :eoy 
            and absence_type_id = :category_id
            and absence_status_id in ([template::util::tcl_to_sql_list [im_sub_categories [im_user_absence_status_active]]])
            and owner_id = :user_id" -default 0]
        set requested_days [db_string requested_days "select coalesce(sum(duration_days),0)
            from im_user_absences 
            where start_date::date <= :eoy 
            and absence_type_id = :category_id
            and absence_status_id in ([template::util::tcl_to_sql_list [im_sub_categories [im_user_absence_status_requested]]])
            and owner_id = :user_id" -default 0]

        set remaining_days [expr $entitlement_days - $absence_days]

        # We need to substract the requested days as well
        set remaining_days [expr $remaining_days - $requested_days]
    } else {
        set absence_days [db_string absence_days "select coalesce(sum(duration),0)
            from im_user_absences 
            where start_date::date <= :eoy 
            and absence_type_id = :category_id
            and absence_status_id in ([template::util::tcl_to_sql_list [im_sub_categories [im_user_absence_status_active]]])
            and owner_id = :user_id
            $ignore_absence_sql" -default 0]
        set remaining_days [expr $entitlement_days - $absence_days]
        set requested_days 0
    } 
    
    if {$remaining_days != 0 || $requested_days !=0} {
        append absence_type_html "    
        <tr>
          <td align='left' valign='top' class='attribute' width='20%'>$absence_type</td>
          <td align='left' valign='top' class='value'>$remaining_days</td>
          <td align='left' valign='top' class='value'>$requested_days</td>
        </tr>"
    }
}

