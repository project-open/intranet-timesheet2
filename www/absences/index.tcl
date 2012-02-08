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
    @author Alwin Egger (alwin.egger@gmx.net)
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

# ---------------------------------------------------------------
# 2. Defaults & Security
# ---------------------------------------------------------------

set user_id [ad_maybe_redirect_for_registration]
set admin_p [im_is_user_site_wide_or_intranet_admin $user_id]
set current_user_id $user_id
set subsite_id [ad_conn subsite_id]
set add_absences_for_group_p [im_permission $user_id "add_absences_for_group"]
set add_hours_all_p [im_permission $user_id "add_hours_all"]
set view_absences_all_p [im_permission $user_id "view_absences_all"]
set add_absences_p [im_permission $user_id "add_absences"]
set org_absence_type_id $absence_type_id


set today [db_string today "select now()::date"]

if {![im_permission $user_id "view_absences"] && !$view_absences_all_p} { 
    ad_return_complaint 1 "You don't have permissions to see absences"
    ad_script_abort
}

# "user_id_from_search" is the guy we're going to log absences for.
# reset this variable to the current user if undefined or if the user doesn't have
# the permission to log hours/absences for other user.
if {"" != $user_id_from_search && $add_hours_all_p} { 
    set user_selection $user_id_from_search
}

if {!$view_absences_all_p} {
    set user_selection "mine"
}


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
set absences_url "/intranet-timesheet2/absences"
set return_url [im_url_with_query]

set user_view_page "/intranet/users/view"
set absence_view_page "$absences_url/new"

set user_selection_types [list "all" "All" "mine" "Mine" "employees" "Employees" "providers" "Providers" "customers" "Customers"]

# Users can only see their own absences, unless they have a special permission
if {!$view_absences_all_p} {
    set user_selection_types [list "mine" "Mine"]
}

if {$add_hours_all_p} {
    # Add employees to user_selection
    set emp_sql "
	select	im_name_from_user_id(user_id) as name,
		user_id
	from	cc_users u,
		group_approved_member_map gamm
	where	u.user_id = gamm.member_id
		and gamm.group_id = [im_employee_group_id]
	order by lower(im_name_from_user_id(user_id))
    "
    db_foreach emps $emp_sql {
	lappend user_selection_types $user_id
	lappend user_selection_types $name
    }
}

foreach { value text } $user_selection_types {
    lappend user_selection_type_list [list $text $value]
}

set timescale_types [list \
			 "all" "All" \
			 "today" "Today" \
			 "next_3w" "Next 3 Weeks" \
			 "next_3m" "Next_3_months" \
			 "future" "Future" \
			 "past" "Past" \
			 "last_3m" "Last_3_months" \
			 "last_3w" "Last 3 Weeks" \
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

set absences_types [im_memoize_list select_absences_types "select absence_type_id, absence_type from im_absence_types order by lower(ABSENCE_TYPE)"]
set absences_types [linsert $absences_types 0 "All"]
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

set bind_vars [ns_set create]
if { ![empty_string_p $user_selection] } {

    if { "mine"==$user_selection } {
            lappend criteria "a.owner_id = :current_user_id"
    } else {
	if {$view_absences_all_p} {
	    switch $user_selection {
		"all" {
		    # Nothing.
		}
		"employees" {
                        lappend criteria "a.owner_id IN (select	m.member_id
                                                        from	group_approved_member_map m
                                                        where	m.group_id = [im_employee_group_id]
                                                        )"

        	}
		"providers" {
                        lappend criteria "a.owner_id IN (select	m.member_id 
							from	group_approved_member_map m 
							where	m.group_id = [im_freelance_group_id]
							)"
		}
                "customers" {
                        lappend criteria "a.owner_id IN (select	m.member_id
                                                        from	group_approved_member_map m
                                                        where	m.group_id = [im_customer_group_id]
                                                        )"
                }  default  {
		    if {[string is integer $user_selection]} {
			lappend criteria "a.owner_id = :user_selection"
		    } else {
			ad_return_complaint 1 "Invalid User Selection:<br>Value '$user_selection' is not a user_id or one of {mine|all|employees|providers|customers}."
		    }
		}
	    }
 	    ns_set put $bind_vars user_selection $user_selection
 	} else {
	    lappend criteria "a.owner_id=:user_id"
	}

    }
    switch $user_selection {
	"mine" {
	    #ns_set put $bind_vars user_selection $user_selection
	    lappend criteria "a.owner_id=:user_id"
	}
	"all" {
	    ns_set put $bind_vars user_selection $user_selection
	}
    }
}

if { ![empty_string_p $absence_type_id] &&  $absence_type_id != -1 } {
     #ns_set put $bind_vars absence_type_id $absence_type_id
     lappend criteria "a.absence_type_id = :absence_type_id"
}

switch $timescale {
    "all" { }
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


if {"" != $start_date} {
    lappend criteria "a.end_date >= :start_date::timestamptz"
}
if {"" != $end_date} {
    lappend criteria "a.start_date <= :end_date::timestamptz"
}



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


set perm_clause "and owner_id = :user_id"
if {$view_absences_all_p} { set perm_clause "" }

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
	im_name_from_user_id(a.owner_id) as owner_name
from
	im_user_absences a
where
	1=1 
	$where_clause
	$perm_clause
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
        {user_selection:text(select),optional {label "[_ intranet-timesheet2.Show_Users]"} {options $user_selection_type_list }}
        {timescale:text(select),optional {label "[_ intranet-timesheet2.Timescale]"} {options $timescale_type_list }}
	{start_date:text(text) {label "[_ intranet-timesheet2.Start_Date]"} {html {size 10}} {value "$start_date"} {after_html {<input type="button" style="height:23px; width:23px; background: url('/resources/acs-templating/calendar.gif');" onclick ="return showCalendar('start_date', 'y-m-d');" >}}}
	{end_date:text(text) {label "[_ intranet-timesheet2.End_Date]"} {html {size 10}} {value "$end_date"} {after_html {<input type="button" style="height:23px; width:23px; background: url('/resources/acs-templating/calendar.gif');" onclick ="return showCalendar('end_date', 'y-m-d');" >}}}
    }


eval [template::adp_compile -string {<formtemplate style="tiny-plain" id="absence_filter"></formtemplate>}]
set filter_html $__adp_output



# ----------------------------------------------------------
# Do we have to show administration links?

set admin_html ""
if {$add_absences_p} {
    set for_user_id ""
    if {[string is integer $user_selection]} { set for_user_id $user_selection }
    
set admin_html "
	<ul>
	<li><a href=[export_vars -base "$absences_url/new" {{user_id_from_search $for_user_id} {return_url}}]>[_ intranet-timesheet2.Add_a_new_Absence]</a></li>
    "
}

set read_p [db_string report_perms "
        select  im_object_permission_p(m.menu_id, :current_user_id, 'read')
        from    im_menus m
        where   m.label = 'capacity-planning'
" -default 'f']

if {[string equal "t" $read_p]} {
    set cap_link [lang::message::lookup "" intranet-core.CapacityPlanning "Capacity Planning"]
    append admin_html "<li><a href='/intranet-timesheet2/absences/capacity-planning'>$cap_link</a></li></ul>"
} else {
    append admin_html "</ul>"
}

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

set index 0
db_foreach cols $col_sql {
    if { "" == $aux_string2 } {
	# set index [expr $category_id - 5000]
	set col [lindex $color_list $index]
	incr index
    } else {
	set col $aux_string2
    }
    if { "t" == $enabled_p  } {
	regsub -all " " $category "_" category_key
	set category_l10n [lang::message::lookup "" intranet-core.$category_key $category]
	append admin_html "<tr><td bgcolor='\#$col' style='padding:3px'>$category_l10n</td></tr>\n"
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
set absence_cube_html [im_absence_cube \
			   -absence_status_id $status_id \
			   -absence_type_id $org_absence_type_id \
			   -user_selection $user_selection \
			   -timescale $timescale \
			   -report_start_date $org_start_date \
			   -user_id_from_search $user_id_from_search \
]

