# /packages/intranet-timesheet2/www/leave-entitlements/remaining-vacation.tcl
#
# Copyright (C) 1998-2004 various parties
# The software is based on ArsDigita ACS 3.4
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

    @param absence_type_id Type of absence we want to report on
    @param reference_date Reference Date on which we count the vacation days
    
    @author malte.sussdorff@cognovis.de

} {
    { reference_date "" }
    { view_name "remaining_vacation_list" }
    { absence_type_id "[im_user_absence_type_vacation]"}
    { employee_status_id:integer ""}
    { view_type "" }
    { department_id ""}
    { user_selection ""}
    { order_by "" }
}


# ---------------------------------------------------------------
# 2. Defaults & Security
# ---------------------------------------------------------------

# User id already verified by filters

set show_context_help_p 0
set filter_admin_html ""
set user_id [ad_maybe_redirect_for_registration]
set admin_p [im_is_user_site_wide_or_intranet_admin $user_id]
set subsite_id [ad_conn subsite_id]
set current_user_id $user_id
set today [lindex [split [ns_localsqltimestamp] " "] 0]
set page_title "[_ intranet-timesheet2.Leave_entitlements]"
set context_bar [im_context_bar $page_title]
set return_url [im_url_with_query]
set name_order [parameter::get -package_id [apm_package_id_from_key intranet-core] -parameter "NameOrder" -default 1]

# Put security code in here.


if {"" == $reference_date} { set reference_date $today }

# ---------------------------------------------------------------
# 3. Defined Table Fields
# ---------------------------------------------------------------

# Define the column headers and column contents that 
# we want to show:
#

set view_id [db_string get_view_id "select view_id from im_views where view_name=:view_name" -default 0]
if {!$view_id } {
    ad_return_complaint 1 "<b>Unknown View Name</b>:<br>
    The view '$view_name' is not defined. <br>
    Maybe you need to upgrade the database. <br>
    Please notify your system administrator."
    return
}

set column_headers [list]
set column_vars [list]
set column_headers_admin [list]
set extra_selects [list]
set extra_froms [list]
set extra_wheres [list]
set view_order_by_clause ""

set column_sql "
select
	vc.*
from im_view_columns vc where
	view_id=:view_id
	and group_id is null
order by
	sort_order"

db_foreach column_list_sql $column_sql {

    set admin_html ""
    if {$admin_p} { 
        set url [export_vars -base "/intranet/admin/views/new-column" {column_id return_url}]
        set admin_html "<a href='$url'>[im_gif wrench ""]</a>" 
    }

    if {"" == $visible_for || [eval $visible_for]} {
        lappend column_headers "[lang::util::localize $column_name]"
        lappend column_vars "$column_render_tcl"
        lappend column_headers_admin $admin_html
        if {"" != $extra_select} { lappend extra_selects $extra_select }
        if {"" != $extra_from} { lappend extra_froms $extra_from }
        if {"" != $extra_where} { lappend extra_wheres $extra_where }
        if {"" != $order_by_clause} {
            set order_by_p([lang::util::localize $column_name]) 1
            if {$order_by==$column_name} {
                set view_order_by_clause $order_by_clause
            }
        }
    }
}

# ---------------------------------------------------------------
# Filter with Dynamic Fields
# ---------------------------------------------------------------

set form_id "remaining_vacation_filter"
set action_url "/intranet-timesheet2/leave-entitlements/remaining-vacation"
set form_mode "edit"

set absences_types [im_memoize_list select_absences_types "select absence_type_id, absence_type from im_user_absence_types
    where absence_type_id in ([template::util::tcl_to_sql_list [im_sub_categories [im_user_absence_type_vacation]]])
    order by lower(absence_type)"]
    
set absence_type_list [list]
foreach { value text } $absences_types {
    # Visible Check on the category
    if {![im_category_visible_p -category_id $value]} {continue}
    regsub -all " " $text "_" category_key
    set text [lang::message::lookup "" intranet-core.$category_key $text]
    lappend absence_type_list [list $text $value]
}

set user_selection_options [im_user_timesheet_absences_options -user_selection $user_selection]


ad_form \
    -name $form_id \
    -action $action_url \
    -mode $form_mode \
    -method GET \
    -export {order_by}\
    -form {

        {user_selection:text(select),optional
            {label "[_ intranet-timesheet2.Show_Users]"}
            {options $user_selection_options}
            {value $user_selection}}

        {absence_type_id:text(select) 
            {label "[_ intranet-timesheet2.Absence_Type]"} 
            {value $absence_type_id} 
            {options $absence_type_list }}
    }


# List to store the view_type_options
set view_type_options [list [list HTML ""]]


## Deal with user filters
im_dynfield::append_attributes_to_form \
    -object_type "person" \
    -form_id $form_id \
    -page_url "/intranet-timesheet2/leave-entitlements/remaining-vacation" \
    -advanced_filter_p 1 \
    -object_id 0

ad_form -extend -name $form_id -form {
    {reference_date:text(text) {label "[_ intranet-timesheet2.Start_Date]"} {value "$reference_date"} {html {size 10}} {after_html {<input type="button" style="height:20px; width:20px; background: url('/resources/acs-templating/calendar.gif');" onclick ="return showCalendar('reference_date', 'y-m-d');" >}}}
}

# Set the form values from the HTTP form variable frame
im_dynfield::set_form_values_from_http -form_id $form_id

array set extra_sql_array [im_dynfield::search_sql_criteria_from_form \
			       -form_id $form_id \
			       -object_type "person"
			  ]


# Run callback to extend the filter and/or add items to the view_type_options
callback im_projects_index_filter -form_id $form_id
ad_form -extend -name $form_id -form {
    {view_type:text(select),optional {label "#intranet-openoffice.View_type#"} {options $view_type_options}}
}

# ---------------------------------------------------------------
# 5. Generate SQL Query
# ---------------------------------------------------------------

set where_clause ""
im_absence_component__user_selection \
    -where_clauseVar where_clause \
    -user_selection_column "employee_id" \
    -user_selection $user_selection \
    -hide_colors_pVar hide_colors_p

# __user_selection already adds current_user_id when showing a department
# so no need for the commented-out code below:
#
# if { $where_clause ne {} } {
#    set where_clause "and (employee_id = :current_user_id or $where_clause)"
# }

if { $employee_status_id ne {} } {
    append where_clause "and employee_status_id=:employee_status_id"
}

if {$view_order_by_clause != ""} {
    set order_by_clause "order by $view_order_by_clause"
} else {
    set order_by_clause "order by owner_name"
}

set extra_select [join $extra_selects ","]
if { ![empty_string_p $extra_select] } {
    set extra_select ",$extra_select"
}

set extra_from [join $extra_froms ","]
if { ![empty_string_p $extra_from] } {
    set extra_from ",$extra_from"
}

if { $extra_wheres ne {} } {
    append where_clause " and [join $extra_wheres " and "] "
}

set booking_year [string range $reference_date 0 3]
set eoy "${booking_year}-12-31"
set soy "${booking_year}-01-01"

# Create a ns_set with all local variables in order
# to pass it to the SQL query
set form_vars [ns_set create]
foreach varname [info locals] {

    # Don't consider variables that start with a "_", that
    # contain a ":" or that are array variables:
    if {"_" == [string range $varname 0 0]} { continue }
    if {[regexp {:} $varname]} { continue }
    if {[array exists $varname]} { continue }

    # Get the value of the variable and add to the form_vars set
    set value [expr "\$$varname"]
    ns_set put $form_vars $varname $value
}

# Add the DynField variables to $form_vars
set dynfield_extra_where $extra_sql_array(where)
set ns_set_vars $extra_sql_array(bind_vars)
set tmp_vars [util_list_to_ns_set $ns_set_vars]
set tmp_var_size [ns_set size $tmp_vars]
for {set i 0} {$i < $tmp_var_size} { incr i } {
    set key [ns_set key $tmp_vars $i]
    set value [ns_set get $tmp_vars $key]
    set $key $value
    ns_set put $form_vars $key $value
}


# Add the additional condition to the "where_clause"
if {"" != $dynfield_extra_where} { 
    append extra_where "and im_employees.employee_id in $dynfield_extra_where"
}

# Get a table with
# - Username (from the owner of the absence /leave entitlement)
# - Department of the owner
# - Vacation already taken (in the current year)
# - Vacation days left (in the current year)
# - Vacation approved yet coming up this year
# Grouping should be by vacation type
# Ordering should be by default by the owner




# Fill Has values for each employee that is visible
set active_category_ids [template::util::tcl_to_sql_list [im_sub_categories [im_user_absence_status_active]]]
set requested_category_ids [template::util::tcl_to_sql_list [im_sub_categories [im_user_absence_status_requested]]]

set sql "select *, 
     entitlement_days_total - total_absence_days - requested_absence_days_this_year as remaining_vacation_days 
     from (
select employee_id,im_name_from_user_id(employee_id,:name_order) as owner_name,im_cost_center_name_from_id(department_id) as department_name, (
        select coalesce(sum(duration_days),0) from im_user_absences
        where start_date::date <= to_date(:eoy,'YYYY-MM-DD')
        and absence_status_id in ($active_category_ids)
        and absence_type_id = :absence_type_id
        and employee_id = owner_id
    ) as total_absence_days,
    ( select coalesce(sum(duration_days),0) from im_user_absences
        where start_date::date <= to_date(:reference_date,'YYYY-MM-DD')
        and start_date::date >= to_date(:soy,'YYYY-MM-DD')
        and absence_status_id in ($active_category_ids)
        and absence_type_id = :absence_type_id
        and employee_id = owner_id
    ) as taken_absence_days_this_year,
    ( select coalesce(sum(duration_days),0) from im_user_absences
        where start_date::date > to_date(:reference_date,'YYYY-MM-DD')
        and start_date::date <= to_date(:eoy,'YYYY-MM-DD')
        and absence_status_id in ($active_category_ids)
        and absence_type_id = :absence_type_id
        and employee_id = owner_id
    ) as remaining_absence_days_this_year,
    ( select coalesce(sum(duration_days),0) from im_user_absences
      where start_date::date >= to_date(:soy,'YYYY-MM-DD')
      and start_date::date <= to_date(:eoy,'YYYY-MM-DD')
      and absence_status_id in ($requested_category_ids)
      and absence_type_id = :absence_type_id
      and employee_id = owner_id
    ) as requested_absence_days_this_year,
    (select coalesce(sum(entitlement_days),0) from im_user_leave_entitlements 
     where owner_id = employee_id 
     and leave_entitlement_type_id = :absence_type_id
     and booking_date <= to_date(:eoy,'YYYY-MM-DD')
     and booking_date >= to_date(:soy,'YYYY-MM-DD')) as entitlement_days_this_year,
    (select coalesce(sum(entitlement_days),0) from im_user_leave_entitlements 
     where owner_id = employee_id
     and leave_entitlement_type_id = :absence_type_id
     and booking_date <= to_date(:eoy,'YYYY-MM-DD')) as entitlement_days_total
    from im_employees , cc_users 
    where	cc_users.user_id = im_employees.employee_id
        and cc_users.member_state = 'approved'
    $where_clause
    $order_by_clause) absences
"

# ---------------------------------------------------------------
# 6. Format the Filter
# ---------------------------------------------------------------

# Note that we use a nested table because im_slider might
# return a table with a form in it (if there are too many
# options


# ----------------------------------------------------------
# Do we have to show administration links?

ns_log Notice "/intranet/project/index: Before admin links"
set admin_html "<ul>"

# Append user-defined menus
set bind_vars [list return_url $return_url]
append admin_html [im_menu_ul_list -no_uls 1 "projects_admin" $bind_vars]
append admin_html "</ul>"

# ---------------------------------------------------------------
# 7. Format the List Table Header
# ---------------------------------------------------------------

# Set up colspan to be the number of headers + 1 for the # column
set colspan [expr [llength $column_headers] + 1]

set table_header_html ""

# Format the header names with links that modify the
# sort order of the SQL query.
#
set url "remaining-vacation?"
set query_string [export_ns_set_vars url [list order_by]]
if { ![empty_string_p $query_string] } {
    append url "$query_string&"
}

append table_header_html "<tr>\n"
set ctr 0
foreach col $column_headers {
    set wrench_html [lindex $column_headers_admin $ctr]
    regsub -all " " $col "_" col_txt
    set col_txt [lang::message::lookup "" intranet-core.$col_txt $col]
    if {[info exists order_by_p($col)]} {
        append table_header_html "<td class=rowtitle><a href=\"${url}order_by=[ns_urlencode $col]\">$col_txt</a>$wrench_html</td>\n"
    } else {
        append table_header_html "<td class=rowtitle>$col_txt $wrench_html</td>\n"
    }
    incr ctr
}
append table_header_html "</tr>\n"


# ---------------------------------------------------------------
# 8. Format the Result Data
# ---------------------------------------------------------------

set table_body_html ""
set bgcolor(0) " class=roweven "
set bgcolor(1) " class=rowodd "
set ctr 0


# ---------------------------------------------------------------
# We reuse the projects_index filter callback for the time being
# ---------------------------------------------------------------

callback im_projects_index_before_render -view_name $view_name \
    -view_type $view_type -sql $sql -table_header $page_title -variable_set $form_vars

db_foreach remaining_vacation_query $sql {
    if {$taken_absence_days_this_year == 0 && $remaining_absence_days_this_year == 0 && $requested_absence_days_this_year == 0 && $entitlement_days_this_year == 0} {continue}

    set remaining_vacation_days [expr $entitlement_days_total - $total_absence_days - $requested_absence_days_this_year]
    set owner_name [im_name_from_user_id $employee_id]
    # Append together a line of data based on the "column_vars" parameter list
    set row_html "<tr$bgcolor([expr $ctr % 2])>\n"
    foreach column_var $column_vars {
        append row_html "\t<td valign=top>"
        set cmd "append row_html $column_var"
        if [catch {
            eval "$cmd"
        } errmsg] {
            # TODO: warn user
        }
        append row_html "</td>\n"
    }
    append row_html "</tr>\n"
    append table_body_html $row_html
    
    incr ctr
}

# Show a reasonable message when there are no result rows:
if { [empty_string_p $table_body_html] } {
    set table_body_html "
        <tr><td colspan=$colspan><ul><li><b> 
No users        </b></ul></td></tr>"
}

# ---------------------------------------------------------------
# Navbars
# ---------------------------------------------------------------

# Get the URL variables for pass-though
set query_pieces [split [ns_conn query] "&"]
set pass_through_vars [list]
foreach query_piece $query_pieces {
    if {[regexp {^([^=]+)=(.+)$} $query_piece match var val]} {
	# exclude "form:...", "__varname" and "letter" variables
	if {[regexp {^form} $var match]} {continue}
	if {[regexp {^__} $var match]} {continue}
	if {[regexp {^letter$} $var match]} {continue}
	set var [ns_urldecode $var]
	lappend pass_through_vars $var
    }
}


# Compile and execute the formtemplate if advanced filtering is enabled.
eval [template::adp_compile -string {<formtemplate id="$form_id" style="tiny-plain-po"></formtemplate>}]
set filter_html $__adp_output

# Left Navbar is the filter/select part of the left bar
set left_navbar_html "
	<div class='filter-block'>
        	<div class='filter-title'>
	           #intranet-core.Filter_Projects# $filter_admin_html
        	</div>
            	$filter_html
      	</div>
      <hr/>
"
