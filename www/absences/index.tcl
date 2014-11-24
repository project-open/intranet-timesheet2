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
    { filter_status_id:integer "" }
    { start_idx:integer 0 }
    { order_by "User" }
    { how_many "" }
    { absence_type_id:integer "5000" }
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
set admin_p [im_is_user_site_wide_or_intranet_admin $user_id]
set current_user_id $user_id
set subsite_id [ad_conn subsite_id]
set add_absences_for_group_p [im_permission $user_id "add_absences_for_group"]
set add_absences_all_p [im_permission $user_id "add_absences_all"]
set view_absences_all_p [expr [im_permission $user_id "view_absences_all"] || $add_absences_all_p]
set add_absences_direct_reports_p [im_permission $user_id "add_absences_direct_reports"]
set view_absences_direct_reports_p [expr [im_permission $user_id "view_absences_direct_reports"] || $add_absences_direct_reports_p]
set add_absences_p [im_permission $user_id "add_absences"]
set org_absence_type_id $absence_type_id
set show_context_help_p 1
set name_order [parameter::get -package_id [apm_package_id_from_key intranet-core] -parameter "NameOrder" -default 1]

set hide_colors_p 0

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

set all_user_options [im_user_options -include_empty_p 0 -group_name "Employees"]
set direct_reports_options [im_user_direct_reports_options -user_id $current_user_id]
set direct_report_ids [im_user_direct_reports_ids -user_id $current_user_id]

if {"" != $user_id_from_search} { set user_selection $user_id_from_search }

if {![im_permission $user_id "view_absences"] && !$view_absences_all_p && !$view_absences_direct_reports_p} { 
    ad_return_complaint 1 "You don't have permissions to see absences"
    ad_script_abort
}

# Support display of all Absences regardless of status in the
# list. This does not show up in grafik though
set absence_status_sql ""
if {$filter_status_id ne {}} {
    set absence_status_sql "and a.absence_status_id = :filter_status_id"
}

# Setting list of "direct reports" and "other employees"
set direct_reports_list [list]
set other_employees_list [list]
if { $view_absences_direct_reports_p || $add_absences_all_p || $view_absences_all_p } {
    set emp_sql "
	SELECT distinct
		im_name_from_user_id(cc.user_id, $name_order) as name,
		cc.user_id,
		e.supervisor_id
	FROM
		group_member_map gm,
		membership_rels mr,
		acs_rels r,
		cc_users cc,
		im_employees e
	WHERE
		gm.rel_id = mr.rel_id
		AND r.rel_id = mr.rel_id
		AND r.rel_type = 'membership_rel'
		AND e.employee_id = gm.member_id
		AND cc.member_state = 'approved'
		AND cc.user_id = gm.member_id
		AND gm.group_id = [im_employee_group_id]
	order by
		name
    "
    db_foreach emps $emp_sql {
        if { $supervisor_id == $current_user_id } {
	        lappend direct_reports_list [list "&nbsp;&nbsp;$name" $user_id]
        } else {
	        lappend other_employees_list [list "&nbsp;&nbsp;$name" $user_id]
        }
    }
}

set user_name $user_selection

set user_selection_type $user_selection
# Check if we have a user_id or a department_id
if {[string is integer $user_selection]} {
    # Find out the object_type
    set object_type [db_string object_type "select object_type from acs_objects where object_id = :user_selection" -default ""]
    switch $object_type {
	im_cost_center {
	    set user_name [im_cost_center_name $user_selection]
	    # Allow the manager to see the department
        ns_log Notice "User:: $user_id $user_selection"
	    if {![im_manager_of_cost_center_p -user_id $current_user_id -cost_center_id $user_selection] && !$view_absences_all_p} {
            # Not a manager => Only see yourself
            set user_selection_type "mine"
	    } else {
            set cost_center_id $user_selection
            set user_selection_type "cost_center"
            set user_selection $cost_center_id
	    }
	}
	user {
	    set user_name [im_name_from_user_id $user_selection]
	    set user_id $user_selection

	    # Check for permissions if we are allowed to see this user
        # NOTE: This is legacy code. We should turn list of absences into a component
        # just like we did for Absence Cube and Absence Calendar. This is a huge hack.
	    if {![im_absence_component_view_p -owner_id $user_selection -current_user_id $current_user_id]} {
            set user_selection_type "mine"
	    }	      
	}
	im_project {
        set project_id $user_selection
	    # Permission Check
	    set project_manager_p [im_biz_object_member_p -role_id 1301 $current_user_id $project_id]
	    if {!$project_manager_p && !$view_absences_all_p} {
            set user_selection_type "mine"
	    } else {
            set user_name [db_string project_name "select project_name from im_projects where project_id = :project_id" -default ""]
            set hide_colors_p 1
            set user_selection_type "project"
            set user_selection $project_id
	    }
	}
	default {
	    ad_return_complaint 1 "Invalid User Selection:<br>Value '$user_selection' is not a user_id, project_id, department_id or one of {mine|all|employees|providers|customers|direct reports}."
	}
    }
}

set page_title "Absences"
set context [list $page_title]
set context_bar [im_context_bar $page_title]
set page_focus "im_header_form.keywords"
set absences_url [parameter::get -package_id [apm_package_id_from_key intranet-timesheet2] -parameter "AbsenceURL" -default "/intranet-timesheet2/absences"]
set return_url [im_url_with_query]
set user_view_page "/intranet/users/view"
set absence_view_page "$absences_url/new"

############################################################
#                                                          #
# ---------- setting filter 'User selection' ------------- # 

# Users can only see their own absences, unless they have a special permission
# ToDo: Users should _always_ see their absences 
if {!$view_absences_all_p} { 
    set user_selection_types [list "mine" "Mine"] 
} else {
    set user_selection_types [list "mine" "Mine" "all" "All"]
}


set emp_sql ""

# Only 'direct' subordinates. 
if {$view_absences_direct_reports_p} { 
    lappend user_selection_types "direct_reports"
    lappend user_selection_types "Direct reports"
    # Add employees to user_selection
    set emp_sql "
	SELECT
        	im_name_from_user_id(cc.user_id, $name_order) as name,
	        cc.user_id
	FROM
        	group_member_map gm,
	        membership_rels mr,
        	acs_rels r,
	        cc_users cc, 
                im_employees e
	WHERE
        	gm.rel_id = mr.rel_id
	        AND r.rel_id = mr.rel_id
        	AND r.rel_type = 'membership_rel'
	        AND cc.user_id = gm.member_id
        	AND cc.member_state = 'approved'
	        AND cc.user_id = gm.member_id
        	AND gm.group_id = [im_employee_group_id]
                AND cc.user_id = e.employee_id
                AND e.supervisor_id = :current_user_id
	order by
		name
    "
}

if {$add_absences_all_p} {
    # Add employees to user_selection
    set emp_sql "
	SELECT
        	im_name_from_user_id(cc.user_id, $name_order) as name,
	        cc.user_id
	FROM
        	group_member_map gm,
	        membership_rels mr,
        	acs_rels r,
	        cc_users cc
	WHERE
        	gm.rel_id = mr.rel_id
	        AND r.rel_id = mr.rel_id
        	AND r.rel_type = 'membership_rel'
	        AND cc.user_id = gm.member_id
        	AND cc.member_state = 'approved'
	        AND cc.user_id = gm.member_id
        	AND gm.group_id = [im_employee_group_id]
	order by
		name
    "

}

set cost_center_options ""
# Deal with the departments
if {$view_absences_all_p} {
    set cost_center_options [im_cost_center_options -include_empty_name [lang::message::lookup "" intranet-core.All "All"] -department_only_p 0]
} else {
    # Limit to Cost Centers where he is the manager
    set cost_center_options [im_cost_center_options -department_only_p 1 -manager_id $current_user_id]
}

if {"" != $cost_center_options} {
    foreach option $cost_center_options {
	lappend user_selection_types [lindex $option 1] 
	lappend user_selection_types [lindex $option 0]
    }
}

# Hide employees from the drop down box for the time being
#db_foreach emps $emp_sql {
#	lappend user_selection_types $user_id
#	lappend user_selection_types $name
#}

# Deal with project managers and display their projects in this list

db_foreach manager_of_project_ids "select distinct r.object_id_one, p.project_nr || ' - ' || p.project_name as project_name
	from acs_rels r, im_biz_object_members bom, im_projects p
	where r.object_id_two = :current_user_id
    and r.rel_id = bom.rel_id
    and p.project_id = r.object_id_one
    and bom.object_role_id = [im_biz_object_role_project_manager]
    and p.project_type_id not in (100,101)
    union select project_id,project_name from im_projects where project_id=:project_id order by project_name" {
    
    lappend user_selection_types $object_id_one
    lappend user_selection_types $project_name

}

# All
if {$add_absences_all_p || $view_absences_all_p} {
    lappend user_selection_types "employees"
    lappend user_selection_types [lang::message::lookup "" intranet-timesheet2.Employees "Employees"] 
    lappend user_selection_types "providers"
    lappend user_selection_types [lang::message::lookup "" intranet-timesheet2.Providers "Providers"] 
    lappend user_selection_types "customers"   
    lappend user_selection_types [lang::message::lookup "" intranet-timesheet2.Customers "Customers"] 
}

# ---------------------------------------------------------------
# Build Drop-down boxes
# ---------------------------------------------------------------

set user_selection_options [im_user_timesheet_absences_options]

# ---------- / setting filter 'User selection' ------------- # 

set timescale_type_list [im_absence_component__timescale_types]

if { ![exists_and_not_null absence_type_id] } {
    # Default type is "all" == -1 - select the id once and memoize it
    set absence_type_id "-1"
}

set end_idx [expr $start_idx + $how_many - 1]
set date_format "YYYY-MM-DD"
set date_time_format "YYYY-MM-DD HH24:MI"

# ---------------------------------------------------------------
# 3. Define Table Columns
# ---------------------------------------------------------------

# Define the column headers and column contents that
# we want to show:
#
set view_id [db_string get_view_id "select view_id from im_views where view_name=:view_name"]
set column_headers [list]
set column_vars [list]
set column_headers_admin [list]

set column_sql "
	select	column_id,
		column_name,
		column_render_tcl,
		visible_for
	from	im_view_columns
	where	view_id=:view_id
		and group_id is null
	order by
		sort_order
"

db_foreach column_list_sql $column_sql {
    if {$visible_for == "" || [eval $visible_for]} {
	lappend column_headers "$column_name"
	lappend column_vars "$column_render_tcl"

	set admin_html ""
	if {$admin_p} { 
	    set url [export_vars -base "/intranet/admin/views/new-column" {column_id return_url}]
	    set admin_html "<a href='$url'>[im_gif wrench ""]</a>" 
	}
	lappend column_headers_admin $admin_html
    }
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


foreach { value text } $user_selection_types {
    lappend user_selection_type_list [list $text $value]
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

        {timescale_date:text(text) 
            {label "[_ intranet-timesheet2.Start_Date]"} 
            {html {size 10}} 
            {value "$timescale_date"} 
            {after_html {<input type="button" style="height:23px; width:23px; background: url('/resources/acs-templating/calendar.gif');" onclick ="return showCalendar('filter_start_date', 'y-m-d');" >}}}

        {timescale:text(select),optional 
            {label "[_ intranet-timesheet2.Timescale]"} 
            {options $timescale_type_list }}

        {absence_type_id:text(select),optional 
            {label "[_ intranet-timesheet2.Absence_Type]"} 
            {value $absence_type_id} 
            {options $absence_type_list }}

        {filter_status_id:text(im_category_tree),optional 
            {label \#intranet-timesheet2.Status\#} 
            {value $filter_status_id} 
            {custom {category_type "Intranet Absence Status" translate_p 1}}}

        {user_selection:text(select),optional 
            {label "[_ intranet-timesheet2.Show_Users]"} 
            {options $user_selection_type_list} 
            {value $user_selection}}

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

set admin_html [im_absence_cube_legend]

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

