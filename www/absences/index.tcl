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
    { status_id:integer "" }
    { start_idx:integer 0 }
    { order_by "User" }
    { how_many "" }
    { absence_type_id:integer "-1" }
    { user_selection "all" }
    { timescale "next_3w" }
    { view_name "absence_list_home" }
    { start_date "" }
    { end_date "" }
    { user_id_from_search "" }
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
set today [db_string today "select now()::date"]

set all_user_options [im_user_options -include_empty_p 0 -group_name "Employees"]
set direct_reports_options [im_user_direct_reports_options -user_id $current_user_id]
set direct_report_ids [im_user_direct_reports_ids -user_id $current_user_id]

if {"" != $user_id_from_search} { set user_selection $user_id_from_search }

if {![im_permission $user_id "view_absences"] && !$view_absences_all_p && !$view_absences_direct_reports_p} { 
    ad_return_complaint 1 "You don't have permissions to see absences"
    ad_script_abort
}


# ---------------------------------------------------------------
# Logic for user_selection
# ---------------------------------------------------------------

# Check if the permissions of the user are restricted
if {!$view_absences_all_p} {
    if {$view_absences_direct_reports_p} {
	# The user can see the absences of his direct reports
	switch $user_selection {
	    all { set user_selection "direct_reports" }
	    mine - direct_reports {
		# Do nothing
	    }
	    default {
		if {[string is integer $user_selection]} {
		    # Only allowed to see absences from direct reports
		    if {[lsearch $direct_report_ids $user_selection] < 0} {
			set user_selection "mine"
		    }
		} else {
		    # Some kind of unknown option was selected
		    set user_selection "direct_reports"
		}
	    }
	}
    } else {
	# The user can only see his own absences
	set user_selection "mine"
    }
}

# ad_return_complaint 1 "user_selection=$user_selection, view_absences_all_p=$view_absences_all_p"


# ---------------------------------------------------------------
# 
# ---------------------------------------------------------------

set user_name $user_selection
if {[string is integer $user_selection]} {
    set user_name [im_name_from_user_id $user_selection]
} else {
    set user_name [lang::message::lookup "" intranet-core.$user_selection $user_selection]
}

set page_title "[lang::message::lookup "" intranet-timesheet2.Absences_for_user "Absences for %user_name%"]"
set context [list $page_title]
set context_bar [im_context_bar $page_title]
set page_focus "im_header_form.keywords"
set absences_url [parameter::get -package_id [apm_package_id_from_key intranet-timesheet2] -parameter "AbsenceURL" -default "/intranet-timesheet2/absences"]
set return_url [im_url_with_query]
set user_view_page "/intranet/users/view"
set absence_view_page "$absences_url/new"


# ---------------------------------------------------------------
# Build Drop-down boxes
# ---------------------------------------------------------------

set user_selection_options [im_user_timesheet_absences_options -enable_groups_p 1]

set timescale_types [list \
			 "all" [lang::message::lookup "" intranet-timesheet2.All "All"] \
			 "custom" [lang::message::lookup "" intranet-timesheet2.CustomTimescale "Start/End Date"] \
			 "today" [lang::message::lookup "" intranet-timesheet2.Today "Today"] \
			 "next_3w" [lang::message::lookup "" intranet-timesheet2.Next_3_Weeks "Next 3 Weeks"] \
			 "next_3m" [lang::message::lookup "" intranet-timesheet2.Next_3_Month "Next 3 Months"] \
			 "future" [lang::message::lookup "" intranet-timesheet2.Future "Future"] \
			 "past" [lang::message::lookup "" intranet-timesheet2.Past "Past"] \
			 "last_3m" [lang::message::lookup "" intranet-timesheet2.Last_3_Month "Last 3 Months"] \
			 "last_3w" [lang::message::lookup "" intranet-timesheet2.Last_3_Weeks "Last 3 Weeks"] \
]

foreach { value text } $timescale_types {
    lappend timescale_type_list [list $text $value]
}

if { ![exists_and_not_null absence_type_id] } {
    # Default type is "all" == -1 - select the id once and memoize it
    set absence_type_id -1;
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
    regsub -all " " $text "_" category_key
    set text [lang::message::lookup "" intranet-core.$category_key $text]
    lappend absence_type_list [list $text $value]
}

# ---------------------------------------------------------------
# 5. Generate SQL Query
# ---------------------------------------------------------------

# Now let's generate the sql query
set criteria [list]
# Compatibility with older version
switch $user_selection {
    "employees" { set user_selection [im_employee_group_id] }
    "providers" { set user_selection [im_freelance_group_id] }
    "customers" { set user_selection [im_customer_group_id] }
}

switch $user_selection {
    "all" {
	# Nothing.
    }
    "mine" {
	lappend criteria "(a.owner_id = :current_user_id OR a.group_id in (select group_id from group_member_map where member_id = :current_user_id))"
    }
    "direct_reports" {
	set direct_report_ids [im_user_direct_reports_ids -user_id $current_user_id]
	if {[llength $direct_report_ids] > 0} {
	    lappend criteria "a.owner_id in ([join $direct_report_ids ","])"
	}
    }
    default  {
	# Now we assume that user_selection is an integer representing some kind of object
	if {![string is integer $user_selection]} {
	    ad_return_complaint 1 "Invalid User Selection:<br>Value '$user_selection' is not a user_id or one of {mine|all|direct_reports}."
	}

	# Check for Groups
	set user_select_group_p [util_memoize [list db_string user_select_group_p "select count(*) from groups where group_id = $user_selection"]]
	if {$user_select_group_p} {
	    lappend criteria "a.owner_id IN (
		select	m.member_id
		from	group_approved_member_map m
		where	m.group_id = $user_selection
	    )"
	}

	# Check for individual user
	set user_select_user_p [util_memoize [list db_string user_select_group_p "select count(*) from persons where person_id = $user_selection"]]
	if {$user_select_user_p} {
	    lappend criteria "a.owner_id = :user_selection"
	}
    }
}

if { ![empty_string_p $absence_type_id] &&  $absence_type_id != -1 } {
    lappend criteria "a.absence_type_id = :absence_type_id"
}

switch $timescale {
    "all" { 
	set start_date "2000-01-01"
	set end_date "2099-12-31"
    }
    "today" { 
	set start_date $today
	set end_date $today
    }
    "next_3w" { 
	set start_date $today
	set end_date [db_string 3w "select now()::date + 21"]
    }
    "last_3w" { 
	set start_date [db_string 3w "select now()::date - 21"]
	set end_date $today
    }
    "next_1m" { 
	set start_date $today
	set end_date [db_string 3w "select now()::date + 31"]
    }
    "past" { 
	set start_date "2000-01-01"
	set end_date $today
    }
    "future" { 
	set start_date $today
	set end_date "2100-01-01"
    }
    "last_3m" { 
	set start_date [db_string last_3m_start_date "select now()::date -93"]
	set end_date $today
    }
    "next_3m" { 
	set start_date $today
	set end_date [db_string last_3m_start_date "select now()::date +93"]
    }
}

if {"" == $start_date} { set start_date [parameter::get_from_package_key -package_key "intranet-cost" -parameter DefaultStartDate -default "2000-01-01"] }
if {"" == $end_date} { set end_date [parameter::get_from_package_key -package_key "intranet-cost" -parameter DefaultEndDate -default "2100-01-01"] }

set org_start_date $start_date
set org_end_date $end_date

# Limit to start-date and end-date
if {"" != $start_date} { lappend criteria "a.end_date::date >= :start_date" }
if {"" != $end_date} { lappend criteria "a.start_date::date <= :end_date" }

set order_by_clause ""
switch $order_by {
    "Name" { set order_by_clause "order by upper(absence_name), owner_name" }
    "User" { set order_by_clause "order by owner_name, start_date" }
    "Date" { set order_by_clause "order by start_date, owner_name" }
    "Start" { set order_by_clause "order by start_date" }
    "End" { set order_by_clause "order by end_date" }
    "Type" { set order_by_clause "order by absence_type, owner_name" }
    "Status" { set order_by_clause "order by absence_status, owner_name" }
}

set where_clause [join $criteria " and\n	    "]
if { ![empty_string_p $where_clause] } {
    set where_clause " and $where_clause"
}

set sql "
	select
		a.*,
		coalesce(absence_name, absence_id::varchar) as absence_name_pretty,
		substring(a.description from 1 for 40) as description_pretty,
		substring(a.contact_info from 1 for 40) as contact_info_pretty,
		im_category_from_id(absence_status_id) as absence_status,
		im_category_from_id(absence_type_id) as absence_type,
		to_char(a.start_date, :date_format) as start_date_pretty,
		to_char(a.end_date, :date_format) as end_date_pretty,
		im_name_from_user_id(a.owner_id, $name_order) as owner_name
	from
		im_user_absences a
	where	(a.owner_id is null OR a.owner_id not in (
			-- Exclude deleted or disabled users
			select	m.member_id
			from	group_member_map m, 
				membership_rels mr
			where	m.group_id = acs__magic_object_id('registered_users') and 
				m.rel_id = mr.rel_id and 
				m.container_id = m.group_id and
				mr.member_state != 'approved'
		))
		$where_clause
"


# ---------------------------------------------------------------
# 5a. Limit the SQL query to MAX rows and provide << and >>
# ---------------------------------------------------------------

# Limit the search results to N data sets only
# to be able to manage large sites

set limited_query [im_select_row_range $sql $start_idx $end_idx]
# We can't get around counting in advance if we want to be able to
# sort inside the table on the page for only those users in the
# query results
set total_in_limited [db_string projects_total_in_limited "
	select count(*)
	from	im_user_absences a
	where	1=1
		$where_clause
   "]
set selection "$sql $order_by_clause"



# ad_return_complaint 1 "<pre>$selection</pre>"

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
	{absence_type_id:text(select),optional {label "[_ intranet-timesheet2.Absence_Type]"} {options $absence_type_list }}
	{user_selection:text(select),optional {label "[_ intranet-timesheet2.Show_Users]"} {options $user_selection_options }}
	{timescale:text(select),optional {label "[_ intranet-timesheet2.Timescale]"} {options $timescale_type_list }}
	{start_date:text(text) {label "[_ intranet-timesheet2.Start_Date]"} {html {size 10}} {value "$start_date"} {after_html {<input type="button" style="height:23px; width:23px; background: url('/resources/acs-templating/calendar.gif');" onclick ="return showCalendar('start_date', 'y-m-d');" >}}}
	{end_date:text(text) {label "[_ intranet-timesheet2.End_Date]"} {html {size 10}} {value "$end_date"} {after_html {<input type="button" style="height:23px; width:23px; background: url('/resources/acs-templating/calendar.gif');" onclick ="return showCalendar('end_date', 'y-m-d');" >}}}
    }

template::element::set_value $form_id start_date $start_date
template::element::set_value $form_id end_date $end_date
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

set color_list [im_absence_cube_color_list]
set col_sql "
	select	category_id, category, enabled_p, aux_string2
	from	im_categories
	where	
			category_type = 'Intranet Absence Type'
	order by category_id
"

append admin_html "<div class=filter-title>[lang::message::lookup "" intranet-timesheet2.Color_codes "Color Codes"]</div>\n"
append admin_html "<table cellpadding='5' cellspacing='5'>\n"

# Marc Fleischer: A question of color
set index 0
db_foreach cols $col_sql {
    if { "" == $aux_string2 } {
	# set index [expr $category_id - 5000]
	set col [lindex $color_list $index]
	incr index
    } else {
	set col $aux_string2
    }

    if { "t" == $enabled_p } {
	regsub -all " " $category "_" category_key
	set category_l10n [lang::message::lookup "" intranet-core.$category_key $category]
	if { [string length $col] == 6} {
	    # Transform RGB Hex-Values (e.g. #a3b2c4) into Dec-Values
	    set r_bg [expr 0x[string range $col 0 1]]
	    set g_bg [expr 0x[string range $col 2 3]]
	    set b_bg [expr 0x[string range $col 4 5]]
	} elseif { [string length $col] == 3 } {
	    # Transform RGB Hex-Values (e.g. #a3b) into Dec-Values
	    set r_bg [expr 0x[string range $col 0 0]]
	    set g_bg [expr 0x[string range $col 1 1]]
	    set b_bg [expr 0x[string range $col 2 2]]
	} else {
		# color codes can't be parsed -> set a middle value
		set r_bg 127
		set g_bg 127
		set b_bg 127
	}
	# calculate a brightness-value for the color
	# if brightness > 127 the foreground color is black, if < 127 the foreground color is white
	set brightness [expr $r_bg * 0.2126 + $g_bg * 0.7152 + $b_bg * 0.0722]
	set col_fg "fff"
	if {$brightness >= 127} {set col_fg "000"}
	set category_l10n [lang::message::lookup "" intranet-core.$category_key $category]
	append admin_html "<tr><td style='padding:3px; background-color:\#$col; color:\#$col_fg'>$category_l10n</td></tr>\n"
   }
}

append admin_html "</table>\n"

# ---------------------------------------------------------------
# 7. Format the List Table Header
# ---------------------------------------------------------------

# Set up colspan to be the number of headers + 1 for the # column
set colspan [expr [llength $column_headers] + 1]

# Format the header names with links that modify the
# sort order of the SQL query.
#
set table_header_html ""
set url "index?"
set query_string [export_ns_set_vars url [list order_by]]
if { ![empty_string_p $query_string] } {
    append url "$query_string&"
}

append table_header_html "<tr>\n"
set ctr 0

foreach col $column_headers {
    set wrench_html [lindex $column_headers_admin $ctr]
    regsub -all " " $col "_" col_key
    set col_txt [lang::message::lookup "" intranet-core.$col_key $col]
    if { [string equal $order_by $col] } {
	append table_header_html "  <td class=rowtitle>$col_txt$wrench_html</td>\n"
    } else {
	append table_header_html "  <td class=rowtitle><a href=\"${url}order_by=[ns_urlencode $col]\">$col_txt</a>$wrench_html</td>\n"
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
set idx $start_idx
set user_link ""
db_foreach absences_list $selection {

    # Use cached TCL function to implement localization
    set absence_status [im_category_from_id $absence_status_id]
    set absence_type [im_category_from_id $absence_type_id]

    set absence_view_url [export_vars -base "$absences_url/new" {absence_id return_url {form_mode "display"}}]

    # Calculate the link for the user/group for which the absence is valid
    set user_link "<a href=\"[export_vars -base "/intranet/users/view" {{user_id $owner_id}}]\">$owner_name</a>"
    if {"" != $group_id} { set user_link [im_profile::profile_name_from_id -profile_id $group_id] }

    #Append together a line of data based on the "column_vars" parameter list
    append table_body_html "<tr $bgcolor([expr $ctr % 2])>\n"
    foreach column_var $column_vars {
	append table_body_html "\t<td valign=top>"
	set cmd "append table_body_html $column_var"
	eval $cmd
	append table_body_html "</td>\n"
    }
    append table_body_html "</tr>\n"

    incr ctr
    if { $how_many > 0 && $ctr >= $how_many } {
	break
    }
    incr idx
} 

# Show a reasonable message when there are no result rows:
if { [empty_string_p $table_body_html] } {
    set table_body_html "
	<tr><td colspan=$colspan><ul><li><b>
	[_ intranet-timesheet2.lt_There_are_currently_n]
	</b></ul></td></tr>"
}

if { $ctr == $how_many && $end_idx < $total_in_limited } {
    # This means that there are rows that we decided not to return
    # Include a link to go to the next page
    set next_start_idx [expr $end_idx + 1]
    set next_page_url "index?start_idx=$next_start_idx&[export_ns_set_vars url [list start_i\
dx]]"
} else {
    set next_page_url ""
}

if { $start_idx > 0 } {
    # This means we didn't start with the first row - there is
    # at least 1 previous row. add a previous page link
    set previous_start_idx [expr $start_idx - $how_many]
    if { $previous_start_idx < 0 } { set previous_start_idx 1 }
    set previous_page_url "index?start_idx=$previous_start_idx&[export_ns_set_vars url [list start_idx]]"
} else {
    set previous_page_url ""
}


# ---------------------------------------------------------------
# 9. Format Table Continuation
# ---------------------------------------------------------------

# nothing to do here ... (?)
set table_continuation_html ""


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



# ---------------------------------------------------------------
# 
# ---------------------------------------------------------------

# Calendar display for vacation days

switch $timescale {
    today { 
	# Just skip(?)
	set absence_cube_html ""
    }
    all { 
	set absence_cube_html [lang::message::lookup "" intranet-timesheet2.AbsenceCubeNotShownAllAbsences "Graphical view of absences not available for Timescale option 'All'. Please choose a different option."]
    }
    past { 
	set absence_cube_html [lang::message::lookup "" intranet-timesheet2.AbsenceCubeNotShownPastAbsences "Graphical view of absences not available for Timescale option 'Past'. Please choose a different option."]
    }
    default {
	set absence_cube_html [im_absence_cube \
				   -absence_status_id $status_id \
				   -absence_type_id $org_absence_type_id \
				   -user_selection $user_selection \
				   -report_start_date $org_start_date \
				   -report_end_date $org_end_date \
				   -user_id_from_search $user_id_from_search \
        ]
    }
}
