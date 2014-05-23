# packages/intranet-timesheet2/www/absence-info.tcl
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

   Display information about the absence

    @author Malte Sussdorff (malte.sussdorff@cognovis.de)
    @creation-date 2014-04-22
    @cvs-id $Id$
} {

} -properties {
} -validate {
} -errors {
}

# -----------------------------------------------------------
# Defaults & Security
# -----------------------------------------------------------
set current_user_id [ad_maybe_redirect_for_registration]

set absence_exists_p [db_string count "select count(*) from im_user_absences where absence_id=:absence_id"]
if {!$absence_exists_p} {
    ad_return_complaint 1 "<b>Error: The selected absence (#$absence_id) does not exist</b>:<br>The absence has probably been deleted by its owner recently."
    ad_script_abort
}
# Check permissions. "See details" is an additional check for
# critical information
callback im_user_absence_perm_check -absence_id $absence_id

im_user_absence_permissions $current_user_id $absence_id view read write admin
set read [im_permission $current_user_id "read_absences_all"]

set actions_html ""

set name_order [parameter::get -package_id [apm_package_id_from_key intranet-core] -parameter "NameOrder" -default 1]

db_1row absence_info {
    select  *,
	        im_name_from_user_id(owner_id, :name_order) as owner_pretty,
	        im_name_from_user_id(vacation_replacement_id, :name_order) as vacation_replacement            
     from   im_user_absences where absence_id = :absence_id
}

set view_name "absence_info"

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



# ---------------------------------------------------------------
# Absence Information
# ---------------------------------------------------------------

# Define the column headers and column contents that we want to show:
#

set view_id [db_string select_view_id "select view_id from im_views where view_name = :view_name" ]
set ctr 1

db_multirow -extend {visible_p td_class column_render} user_columns column_list_sql {	
    select	column_name,
	        column_render_tcl,
            visible_for
	from	im_view_columns
	where	view_id=:view_id
	        and group_id is null
	order by
		    sort_order
} {
    if {"" == $visible_for || [eval $visible_for]} {
        set visible_p 1
	    
	    # Render the column_render
	    set cmd "set column_render $column_render_tcl"
	    eval $cmd

	    # L10n
	    regsub -all " " $column_name "_" column_name_subs
	    set column_name [lang::message::lookup "" intranet-core.$column_name_subs $column_name]

	    # Make sure to have the correct classes
	    if {[expr $ctr % 2]} {
            set td_class "class=rowodd"
	    } else { 
            set td_class "class=roweven"
	    }
	    incr ctr
	} else {
	    # It should not be visible
	    set visible_p 0
	}
}