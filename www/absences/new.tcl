# /packages/intranet-core/www/intranet/companies/new.tcl
#
# Copyright (C) 2004 various parties
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
    Displays the editor for one absence.
    @param absence_id which component should be modified
    @param return_url the url to be send back after the saving

    @author mai-bee@gmx.net
} {
    {absence_id:integer 0}
}

set user_id [ad_maybe_redirect_for_registration]

# Return to this page for edit actions, if not being called
# from another page.
if {[info exists return_url] && "" == $return_url} {
    set return_url [im_url_with_query]
}

set date_format "YYYY-MM-DD"

# ---------------------------------------------------------------
# Permission
# ---------------------------------------------------------------

if {![im_permission $user_id "add_absences"]} {
    ad_return_complaint "[_ intranet-timesheet2.lt_Insufficient_Privileg]" "
    <li>[_ intranet-timesheet2.lt_You_dont_have_suffici]"
}

# ---------------------------------------------------------------
# Get Absence Data
# ---------------------------------------------------------------

if {[info exists absence_id] && $absence_id > 0} {
    set result [db_0or1row absence_data "
	select 
		owner_id,
		description,
		contact_info,
		absence_type_id,
		to_char(a.start_date, :date_format) as start_date,
		to_char(a.end_date, :date_format) as end_date,
		im_name_from_user_id(a.owner_id) as owner_name 
	from 
		im_user_absences a 
	where 
		a.absence_id = :absence_id
	"]

    if { $result != 1 } {
	ad_return_complaint "[_ intranet-timesheet2.Bad_Absence]" "
        <li>[_ intranet-timesheet2.lt_We_couldnt_find_absen]"
	return
    }
    if {$user_id != $owner_id } {
        ad_return_complaint "[_ intranet-timesheet2.lt_Insufficient_Privileg]" "
        <li>[_ intranet-timesheet2.lt_You_dont_have_suffici_1]"
    }
    set page_title "[_ intranet-timesheet2.Edit_Absence]"
    set context_bar [im_context_bar $page_title]

} else {

    set owner_id $user_id
    set absence_id [im_new_object_id]
    db_1row user_name_date "select im_name_from_user_id(:user_id) as owner_name from dual"
    set start_date [db_string get_today "select sysdate from dual"]
    set end_date [db_string get_today "select sysdate from dual"]
    set description ""
    set contact_info ""
    set absence_type_id ""
    set page_title "[_ intranet-timesheet2.New_Absence]"
    set context_bar [im_context_bar $page_title]

}

# ---------------------------------------------------------------
# Get Absence Types from categories
# ---------------------------------------------------------------
set absences_types [im_memoize_list select_absences_types "select absence_type_id, absence_type from im_absence_types order by lower(ABSENCE_TYPE)"]

