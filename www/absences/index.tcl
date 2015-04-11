# /packages/intranet-timesheet2/www/absences/index.tcl
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

ad_page_contract {
    Shows all absences. Filters for type, who and when

    @param absence_type_id	if specified, limits view to absences of this type
    @param user_selection	if specified, limits view to absences to mine or all
    @param timescale		if specified, limits view to absences of this time slice
    @param order_by		Specifies order for the table

    @author mbryzek@arsdigita.com
    @author Frank Bergmann (frank.bergmann@project-open.com)
    @author Klaus Hofeditz (klaus.hofeditz@project-open.com)
    @author Alwin Egger (alwin.egger@gmx.net)
    @author Marc Fleischer (marc.fleischer@leinhaeuser-solutions.de)

} {
    { filter_status_id:integer "[im_user_absence_status_requested_or_active]" }
    { start_idx:integer 0 }
    { order_by "User" }
    { how_many "" }
    { absence_type_id:integer "-1" }
    { user_selection "mine" }
    { timescale "future" }
    { view_name "absence_list_home" }
    { timescale_date "" }
    { user_id_from_search "" }
    { cost_center_id:integer "" }
    { project_id ""}
}

# KH: "watch package" ... instead of setting the watch through GUI   
# ns_eval [source "[acs_root_dir]/packages/intranet-timesheet2/tcl/intranet-absences-procs.tcl"]

# ---------------------------------------------------------------
# 2. Defaults & Security
# ---------------------------------------------------------------

set user_id [ad_maybe_redirect_for_registration]
set current_user_id $user_id
set subsite_id [ad_conn subsite_id]

set add_absences_all_p [im_permission $user_id "add_absences_all"]
set view_absences_all_p [expr [im_permission $user_id "view_absences_all"] || $add_absences_all_p]
set add_absences_direct_reports_p [im_permission $user_id "add_absences_direct_reports"]
set org_absence_type_id $absence_type_id
set show_context_help_p 1


# Support if we pass a project_id in
if {"" != $project_id} {
    set user_selection $project_id
}

if {!$view_absences_all_p} {
    switch $user_selection {
        all - employees {set user_selection "mine"}
        providers - customers {set user_selection "mine"}
    }
}

set today [db_string today "select now()::date"]

if {"" != $user_id_from_search} { set user_selection $user_id_from_search }

if {![im_permission $user_id "view_absences"] && !$view_absences_all_p && !$view_absences_direct_reports_p} { 
    ad_return_complaint 1 "You don't have permissions to see absences"
    ad_script_abort
}

set page_title "Absences"
set context [list $page_title]
set context_bar [im_context_bar $page_title]
set page_focus "im_header_form.keywords"
set return_url [im_url_with_query]
set user_view_page "/intranet/users/view"

# Prepare the subscription link
set salt [db_string salt "select salt from users where user_id = :current_user_id" -default ""]
set token [ns_sha1 "${user_id}${salt}"]
regsub -all {http://} [ad_url] {} server_name
set subscribe_url [export_vars -base "webcal://${server_name}/intranet-timesheet2/absences/ics/${user_id}-${token}.ics" -url {user_selection}]
if {$user_selection eq "mine"} {
    set calname "$owner_name Absences"
} else {
    set calname "[im_name_from_id $user_selection] Absences"
}
set subscribe_link "<a href='$subscribe_url'>$calname</a>"

############################################################
#                                                          #
# ---------- setting filter 'User selection' ------------- # 


set user_selection_options [im_user_timesheet_absences_options -project_id $project_id -user_selection $user_selection]


# ---------- / setting filter 'User selection' ------------- # 

set timescale_type_list [im_absence_component__timescale_types]

if { ![exists_and_not_null absence_type_id] } {
    # Default type is "all" == -1 - select the id once and memoize it
    set absence_type_id "-1"
}



# ---------------------------------------------------------------
# 4. Define Filter Categories
# ---------------------------------------------------------------

# absences_types
set absences_types [im_memoize_list select_absences_types "select absence_type_id, absence_type from im_user_absence_types order by lower(absence_type)"]
set absences_types [linsert $absences_types 0 [lang::message::lookup "" intranet-timesheet2.All "All"]]
set absences_types [linsert $absences_types 0 -1]
set absence_type_list [list]
foreach { value text } $absences_types {
    # Visible Check on the category
    if {![im_category_visible_p -category_id $value]} {continue}
    regsub -all " " $text "_" category_key
    set text [lang::message::lookup "" intranet-core.$category_key $text]
    lappend absence_type_list [list $text $value]
}

# ---------------------------------------------------------------
# 6. Format the Filter
# ---------------------------------------------------------------

set form_id "absence_filter"
set object_type "im_absence"
set action_url "/intranet-timesheet2/absences/"
set form_mode "edit"
ad_form \
    -name $form_id \
    -action $action_url \
    -mode $form_mode \
    -actions [list [list [lang::message::lookup {} intranet-timesheet2.Edit Edit] edit]] \
    -method GET \
    -export {start_idx order_by how_many view_name}\
    -form {

        {user_selection:text(select),optional
            {label "[_ intranet-timesheet2.Show_Users]"}
            {options $user_selection_options}
            {value $user_selection}}

        {absence_type_id:text(select),optional
            {label "[_ intranet-timesheet2.Absence_Type]"}
            {value $absence_type_id}
            {options $absence_type_list }}

        {filter_status_id:text(im_category_tree),optional
            {label \#intranet-timesheet2.Status\#}
            {value $filter_status_id}
            {custom {category_type "Intranet Absence Status" translate_p 1}}}

        {timescale:text(select),optional
            {label "[_ intranet-timesheet2.Timescale]"}
            {options $timescale_type_list }}

        {timescale_date:text(text)
            {label "[_ intranet-timesheet2.Start_Date]"}
            {html {size 10}}
            {value "$timescale_date"}
            {after_html {<input type="button" style="height:23px; width:23px; background: url('/resources/acs-templating/calendar.gif');" onclick ="return showCalendar('timescale_date', 'y-m-d');" >}}}
        {subscribe_link:text(inform)
            {label "[_ intranet-core.Subscribe]"}
            {value $subscribe_link}
        }
    }

template::element::set_value $form_id timescale_date $timescale_date
template::element::set_value $form_id timescale $timescale
template::element::set_value $form_id user_selection $user_selection

eval [template::adp_compile -string {<formtemplate style="tiny-plain-po" id="absence_filter"></formtemplate>}]
set filter_html $__adp_output

# ---------------------------------------------------------------
# Create Links from Menus 
# ---------------------------------------------------------------
set for_user_id $current_user_id

if {[string is integer $user_selection]} { 
    # Log for other user "than current user" requires permissions
    # user_selection can be the current_user, a "direct report" or any other user.

    # Permission to log for any user - OK
    if {$add_absences_all_p} {
        set for_user_id $user_selection
    }

    if {!$add_absences_all_p && $add_absences_direct_reports_p} {
        set direct_reports [im_user_direct_reports_ids -user_id $current_user_id]
        if {[lsearch $direct_reports $user_selection] > -1} {
            set for_user_id $user_selection
        }
    }
}

set admin_html [im_menu_ul_list "timesheet2_absences" [list user_id_from_search $for_user_id return_url $return_url]]

# ----------------------------------------------------------
# Set color scheme 
# ----------------------------------------------------------

append admin_html "[im_absence_cube_legend]"

# ---------------------------------------------------------------
# Left Navbar
# ---------------------------------------------------------------


set left_navbar_html "
	    <div class=\"filter-block\">
		<div class=\"filter-title\">
		[lang::message::lookup "" intranet-timesheet2.Filter_Absences "Filter Absences"]
		</div>
		$filter_html
	    </div>
	    <hr/>

	    <div class=\"filter-block\">
		<div class=\"filter-title\">
		[lang::message::lookup "" intranet-timesheet2.Admin_Absences "Admin Absences"]
		</div>
		$admin_html
	    </div>
"

