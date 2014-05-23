# /packages/intranet-core/www/projects/index.tcl
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
    List all projects with dimensional sliders.

    @param order_by project display order 
    @param include_subprojects_p whether to include sub projects
    @param mine_p:
	"t": Show only mine
	"f": Show all projects
	"dept": Show projects of my department(s)

    @param status_id criteria for project status
    @param project_type_id criteria for project_type_id
    @param letter criteria for im_first_letter_default_to_a(project_name)
    @param start_idx the starting index for query
    @param how_many how many rows to return

    @author mbryzek@arsdigita.com
    @author frank.bergmann@project-open.com
} {
    { order_by "Project nr" }
    { start_date "" }
    { view_name "project_list" }
    { view_type "" }
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

# Put security code in here.


if {"" == $start_date} { set start_date $today }

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
from
	im_view_columns vc
where
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
        if {"" != $order_by_clause && $order_by==$column_name} {
            set view_order_by_clause $order_by_clause
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

ad_form \
    -name $form_id \
    -action $action_url \
    -mode $form_mode \
    -method GET \
    -export {order_by}\
    -form {
        {start_date:text(text) {label "[_ intranet-timesheet2.Start_Date]"} {value "$start_date"} {html {size 10}} {after_html {<input type="button" style="height:20px; width:20px; background: url('/resources/acs-templating/calendar.gif');" onclick ="return showCalendar('start_date', 'y-m-d');" >}}}
        {absence_type_id:text(select),optional {label "[_ intranet-timesheet2.Absence_Type]"} {value $absence_type_id} {options $absence_type_list }}
    }


# List to store the view_type_options
set view_type_options [list [list HTML ""]]

# Run callback to extend the filter and/or add items to the view_type_options
callback im_projects_index_filter -form_id $form_id
ad_form -extend -name $form_id -form {
    {view_type:text(select),optional {label "#intranet-openoffice.View_type#"} {options $view_type_options}}
}

# ---------------------------------------------------------------
# 5. Generate SQL Query
# ---------------------------------------------------------------

set criteria [list]
if { ![empty_string_p $absence_type_id] && $absence_type_id > 0 } {
    lappend criteria "absence_type_id in ([join [im_sub_categories $absence_type_id] ","])"
}

if {![im_user_is_hr_p $user_id]} {
    # Only HR can view all users, everyone only the users he is supervising
    lappend criteria "and owner_id in (select employee_id from im_employees where supervisor_id = :user_id)"
}

# Limit to start-date and end-date
if {"" != $start_date} { lappend criteria "p.end_date::date >= :start_date" }

set order_by_clause "order by lower(project_nr) DESC"
if {$view_order_by_clause != ""} {
    set order_by_clause "order by $view_order_by_clause"
}

set where_clause [join $criteria " and "]
if { ![empty_string_p $where_clause] } {
    set where_clause " and $where_clause"
}

set extra_select [join $extra_selects ","]
if { ![empty_string_p $extra_select] } {
    set extra_select ",$extra_select"
}

set extra_from [join $extra_froms ","]
if { ![empty_string_p $extra_from] } {
    set extra_from ",$extra_from"
}

set extra_where [join $extra_wheres " and "]
if { ![empty_string_p $extra_where] } {
    set extra_where " and $extra_where"
}

# Get a table with
# - Username (from the owner of the absence /leave entitlement)
# - Department of the owner
# - Vacation already taken (in the current year)
# - Vacation days left (in the current year)
# - Vacation approved yet coming up this year
# Grouping should be by vacation type
# Ordering should be by default by the owner

set sql "
    select sum(entitlement_days), sum()

"

# ---------------------------------------------------------------
# 5a. Limit the SQL query to MAX rows and provide << and >>
# ---------------------------------------------------------------

# Limit the search results to N data sets only
# to be able to manage large sites
#

ns_log Notice "/intranet/project/index: Before limiting clause"

if {[string equal $upper_letter "ALL"]} {
    # Set these limits to negative values to deactivate them
    set total_in_limited -1
    set how_many -1
    set selection $sql
} else {
    # We can't get around counting in advance if we want to be able to
    # sort inside the table on the page for only those users in the
    # query results
    set total_in_limited [db_string total_in_limited "
        select count(*)
        from ($sql) s
    "]

    # Special case: FIRST the users selected the 2nd page of the results
    # and THEN added a filter. Let's reset the results for this case:
    while {$start_idx > 0 && $total_in_limited < $start_idx} {
	set start_idx [expr $start_idx - $how_many]
	set end_idx [expr $end_idx - $how_many]
    }

    set selection [im_select_row_range $sql $start_idx $end_idx]
}	

# ---------------------------------------------------------------
# 6. Format the Filter
# ---------------------------------------------------------------

# Note that we use a nested table because im_slider might
# return a table with a form in it (if there are too many
# options

ns_log Notice "/intranet/project/index: Before formatting filter"


set mine_p_options [list \
	[list $all_l10n "f" ] \
	[list [lang::message::lookup "" intranet-core.With_members_of_my_dept "With member of my department"] "dept"] \
	[list [lang::message::lookup "" intranet-core.Mine "Mine"] "t"] \
]

set letter $upper_letter

# ----------------------------------------------------------
# Do we have to show administration links?

ns_log Notice "/intranet/project/index: Before admin links"
set admin_html "<ul>"

if {[im_permission $current_user_id "add_projects"]} {
    append admin_html "<li><a href=\"/intranet/projects/new\">[_ intranet-core.Add_a_new_project]</a></li>\n"

    set new_from_template_p [ad_parameter -package_id [im_package_core_id] EnableNewFromTemplateLinkP "" 0]
    if {$new_from_template_p} {
        append admin_html "<li><a href=\"/intranet/projects/new-from-template\">[lang::message::lookup "" intranet-core.Add_a_new_project_from_Template "Add a new project from Template"]</a></li>\n"
    }

    set wf_oid_col_exists_p [im_column_exists wf_workflows object_type]
    if {$wf_oid_col_exists_p} {
	set wf_sql "
		select	t.pretty_name as wf_name,
			w.*
		from	wf_workflows w,
			acs_object_types t
		where	w.workflow_key = t.object_type
			and w.object_type = 'im_project'
	"
	db_foreach wfs $wf_sql {
	    set new_from_wf_url [export_vars -base "/intranet/projects/new" {workflow_key}]
	    append admin_html "<li><a href=\"$new_from_wf_url\">[lang::message::lookup "" intranet-core.New_workflow "New %wf_name%"]</a></li>\n"
	}
    }
}

# Append user-defined menus
set bind_vars [list return_url $return_url]
append admin_html [im_menu_ul_list -no_uls 1 "projects_admin" $bind_vars]
append admin_html "</ul>"

# ---------------------------------------------------------------
# 7. Format the List Table Header
# ---------------------------------------------------------------

# Set up colspan to be the number of headers + 1 for the # column
ns_log Notice "/intranet/project/index: Before format header"
set colspan [expr [llength $column_headers] + 1]

set table_header_html ""

# Format the header names with links that modify the
# sort order of the SQL query.
#
set url "index?"
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
    if {$ctr == 0 && $show_bulk_actions_p} {
	append table_header_html "<td class=rowtitle>$col_txt$wrench_html</td>\n"
    } else {
	#set col [lang::util::suggest_key $col]
	append table_header_html "<td class=rowtitle><a href=\"${url}order_by=[ns_urlencode $col]\">$col_txt</a>$wrench_html</td>\n"
    }
    incr ctr
}
append table_header_html "</tr>\n"


# ---------------------------------------------------------------
# 8. Format the Result Data
# ---------------------------------------------------------------

ns_log Notice "/intranet/project/index: Before db_foreach"

set table_body_html ""
set bgcolor(0) " class=roweven "
set bgcolor(1) " class=rowodd "
set ctr 0
set idx $start_idx

callback im_projects_index_before_render -view_name $view_name \
    -view_type $view_type -sql $selection -table_header $page_title -variable_set $form_vars

db_1row timeline "
	select	 max(end_date) as timeline_end_date,
		 min(start_date) as timeline_start_date
	from	 ($sql) t
"

db_foreach projects_info_query $selection -bind $form_vars {

    set project_type [im_category_from_id $project_type_id]
    set project_status [im_category_from_id $project_status_id]

    # Multi-Select
    set select_project_checkbox "<input type=checkbox name=select_project_id value=$project_id id=select_project_id,$project_id>"

    set timeline_html [im_project_gantt_main_project \
			   -timeline_start_date $timeline_start_date \
			   -timeline_end_date $timeline_end_date \
			   -timeline_width 400 \
			   -project_id $project_id \
			   -start_date $start_date \
			   -end_date $end_date \
			   -percent_completed $percent_completed \
    ]

    # Gif for collapsable tree?
    set gif_html ""

    set url [im_maybe_prepend_http $url]
    if { [empty_string_p $url] } {
        set url_string "&nbsp;"
    } else {
        set url_string "<a href=\"$url\">$url</a>"
    }
    
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
    if { $how_many > 0 && $ctr > $how_many } {
        break
    }
    incr idx
}

# Show a reasonable message when there are no result rows:
if { [empty_string_p $table_body_html] } {
    set table_body_html "
        <tr><td colspan=$colspan><ul><li><b> 
	[lang::message::lookup "" intranet-core.lt_There_are_currently_n "There are currently no entries matching the selected criteria"]
        </b></ul></td></tr>"
}

if { $end_idx < $total_in_limited } {
    # This means that there are rows that we decided not to return
    # Include a link to go to the next page
    set next_start_idx [expr $end_idx + 0]
    set next_page_url "index?start_idx=$next_start_idx&amp;[export_ns_set_vars url [list start_idx]]"
} else {
    set next_page_url ""
}

if { $start_idx > 0 } {
    # This means we didn't start with the first row - there is
    # at least 1 previous row. add a previous page link
    set previous_start_idx [expr $start_idx - $how_many]
    if { $previous_start_idx < 0 } { set previous_start_idx 0 }
    set previous_page_url "index?start_idx=$previous_start_idx&amp;[export_ns_set_vars url [list start_idx]]"
} else {
    set previous_page_url ""
}

# ---------------------------------------------------------------
# 9. Format Table Continuation
# ---------------------------------------------------------------

ns_log Notice "/intranet/project/index: before table continuation"
# Check if there are rows that we decided not to return
# => include a link to go to the next page
#
if {$total_in_limited > 0 && $end_idx < $total_in_limited} {
    set next_start_idx [expr $end_idx + 0]
    set next_page "<a href=index?start_idx=$next_start_idx&amp;[export_ns_set_vars url [list start_idx]]>Next Page</a>"
} else {
    set next_page ""
}

# Check if this is the continuation of a table (we didn't start with the
# first row - there is at least 1 previous row.
# => add a previous page link
#
if { $start_idx > 0 } {
    set previous_start_idx [expr $start_idx - $how_many]
    if { $previous_start_idx < 0 } { set previous_start_idx 0 }
    set previous_page "<a href=index?start_idx=$previous_start_idx&amp;[export_ns_set_vars url [list start_idx]]>Previous Page</a>"
} else {
    set previous_page ""
}

set table_continuation_html "
<tr>
  <td align=center colspan=$colspan>
    [im_maybe_insert_link $previous_page $next_page]
  </td>
</tr>"

if {$show_bulk_actions_p} {
    set table_continuation_html "
	<tr>
	<td colspan=99>[im_project_action_select]</td>
	</tr>
$table_continuation_html
    "
}


# ---------------------------------------------------------------
# Dashboard column
# ---------------------------------------------------------------

set dashboard_column_html [string trim [im_component_bay "right"]]
if {"" == $dashboard_column_html} {
    set dashboard_column_width "0"
} else {
    set dashboard_column_width "250"
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


set start_date $org_start_date
set end_date $org_end_date
set project_status_id $org_project_status_id
set project_type_id $org_project_type_id
# !!! ad_return_complaint 1 "pass=$pass_through_vars, start_date=$start_date, end_date=$end_date"

# Project Navbar goes to the top
#
set letter $upper_letter
set project_navbar_html [\
			     im_project_navbar \
			     -current_plugin_id $plugin_id \
			     $letter \
			     "/intranet/projects/index" \
			     $next_page_url \
			     $previous_page_url \
			     $pass_through_vars \
			     $menu_select_label \
			    ]

# Compile and execute the formtemplate if advanced filtering is enabled.
eval [template::adp_compile -string {<formtemplate id="project_filter" style="tiny-plain-po"></formtemplate>}]
set filter_html $__adp_output

# Customizing for Kolibri. Do not show the filter to freelancers
if {[im_profile::member_p -user_id $user_id -profile "Freelancers"]} {
    set left_navbar_html ""
} else {
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
}
append left_navbar_html "
      	<div class='filter-block'>
        <div class='filter-title'>
            #intranet-core.Admin_Projects#
        </div>
	$admin_html
      	</div>
"
