# packages/intranet-timesheet2/www/absences/view.tcl
#
# Copyright (c) 2014, cognovís GmbH, Hamburg, Germany
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see
# <http://www.gnu.org/licenses/>.
#

ad_page_contract {

    Display one absence for a user

    @author Malte Sussdorff (malte.sussdorff@cognovis.de)
    @creation-date 2014-04-22
    @cvs-id $Id$
} {
    absence_id
} -properties {
} -validate {
} -errors {
}

# -----------------------------------------------------------
# Defaults & Security
# -----------------------------------------------------------

set return_url [im_url_with_query]
set current_url [ns_conn url]
set current_user_id [ad_maybe_redirect_for_registration]

set owner_id [db_string owner "select owner_id from im_user_absences where absence_id=:absence_id" -default ""]
if {"" == $owner_id} {set owner_id $current_user_id}

callback im_user_absence_perm_check -absence_id $absence_id
im_user_absence_permissions $current_user_id $absence_id view read write admin

set absence_under_wf_control_p [db_string wf_control "
    select	count(*)
    from	wf_cases
    where	object_id = :absence_id
"]

if {"" != $owner_id} {
    if {$absence_under_wf_control_p} {
        set edit_perm_func [parameter::get_from_package_key -package_key intranet-timesheet2 -parameter AbsenceNewPageWfEditButtonPerm -default "im_absence_new_page_wf_perm_edit_button"]
        set delete_perm_func [parameter::get_from_package_key -package_key intranet-timesheet2 -parameter AbsenceNewPageWfDeleteButtonPerm -default "im_absence_new_page_wf_perm_delete_button"]
        if {[eval [list $edit_perm_func -absence_id $absence_id]]} {
            append actions_html "<input type=\"submit\" name=\"formbutton:edit\" value=\"[lang::message::lookup {} intranet-timesheet2.Edit Edit]\">"
        }
        if {[eval [list $delete_perm_func -absence_id $absence_id]]} {
            append actions_html "<input type=\"submit\" name=\"formbutton:delete\" value=\"[lang::message::lookup {} intranet-timesheet2.Delete Delete]\">"
        }
    } else {
        # No workflow control - enable buttons
        if {$write} {
            append actions_html "<input type=\"submit\" name=\"formbutton:edit\" value=\"[lang::message::lookup {} intranet-timesheet2.Edit Edit]\">"
        } 
        if {$admin} {
            append actions_html "<input type=\"submit\" name=\"formbutton:delete\" value=\"[lang::message::lookup {} intranet-timesheet2.Delete Delete]\">"
        }
   }
}

set page_title [lang::message::lookup "" intranet-timesheet2.Absence "Absence"]




