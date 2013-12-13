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
set view_absences_all_p [im_permission $user_id "view_absences_all"]
set view_absences_direct_reports_p [im_permission $user_id "view_absences_direct_reports"]
set add_absences_p [im_permission $user_id "add_absences"]
set org_absence_type_id $absence_type_id
set show_context_help_p 1
set name_order [parameter::get -package_id [apm_package_id_from_key intranet-core] -parameter "NameOrder" -default 1]

set today [db_string today "select now()::date"]

if {![im_permission $user_id "view_absences"] && !$view_absences_all_p && !$view_absences_direct_reports_p} { 
    ad_return_complaint 1 "You don't have permissions to see absences"
    ad_script_abort
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

# Reset this variable to the current user if undefined or if the user doesn't have
# the permission to log absences for other user.
# if {"" != $user_id_from_search && $add_absences_all_p } { 
#    set user_selection $user_id_from_search
# }
# Set default to 'mine' in case user can't see ALL absences 
# if {!$view_absences_all_p } { set user_selection "mine" }

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

# Link "New absence" can't become easily a dynamic link manageable 
# with ADMIN->MENUS due to feature "logging absences for other users" 
# So let's make it configurable  
set absences_url [parameter::get -package_id [apm_package_id_from_key intranet-timesheet2] -parameter "AbsenceURL" -default "/intranet-timesheet2/absences"]

set return_url [im_url_with_query]

set user_view_page "/intranet/users/view"
set absence_view_page "$absences_url/new"

# Show always "mine" 
set user_selection_types [list [list [lang::message::lookup "" intranet-timesheet2.Mine Mine] "mine"]] 

# Direct subordinates 
if {$view_absences_direct_reports_p || $add_absences_all_p || $view_absences_all_p} { 
    if { 0 != [llength $direct_reports_list] } {
	lappend user_selection_types [list [lang::message::lookup "" intranet-timesheet2.Direct_reports "Direct reports"] "direct_reports"]
	foreach list_item $direct_reports_list { lappend user_selection_types $list_item}
    }
}

# All
if {$add_absences_all_p || $view_absences_all_p} {
    lappend user_selection_types [list [lang::message::lookup "" intranet-timesheet2.All "All"] "all"] 
    foreach list_item $other_employees_list { lappend user_selection_types $list_item}
    lappend user_selection_types [list [lang::message::lookup "" intranet-timesheet2.Employees "Employees"] "employees"] 
    lappend user_selection_types [list [lang::message::lookup "" intranet-timesheet2.Providers "Providers"] "providers"] 
    lappend user_selection_types [list [lang::message::lookup "" intranet-timesheet2.Customers "Customers"] "customers"]     
}


# ---------- / setting filter 'User selection' ------------- # 
#
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
		}
		"direct_reports" {
		    lappend criteria "a.owner_id in (
			select employee_id from im_employees
			where supervisor_id = :current_user_id
		    UNION
			select	e.employee_id 
			from	im_employees e,
				-- Select all departments where the current user is manager
				(select	cc.cost_center_id,
					cc.manager_id
				from	im_cost_centers cc,
					(select cost_center_code as code,
						length(cost_center_code) len
					from	im_cost_centers
					where	manager_id = :current_user_id
					) t
				where	substring(cc.cost_center_code for t.len) = t.code
				) tt
			where  e.department_id = tt.cost_center_id
			       OR e.employee_id = tt.manager_id
		    )"
                }  
		default  {
		    if {[string is integer $user_selection]} {
			lappend criteria "a.owner_id = :user_selection"
		    } else {
			ad_return_complaint 1 "Invalid User Selection:<br>Value '$user_selection' is not a user_id or one of {mine|all|employees|providers|customers|direct reports}."
		    }
		}
	    }
 	    ns_set put $bind_vars user_selection $user_selection
	} elseif { $view_absences_direct_reports_p } {
	    if { "direct_reports" == $user_selection } {
		lappend criteria "a.owner_id in (select employee_id from im_employees where supervisor_id = :current_user_id)"
	    } else {
		# Show always own absences
		lappend criteria "a.owner_id=:user_id"
	    }
 	} else {
	    lappend criteria "a.owner_id=:user_id"
	}
    }
    switch $user_selection {
	"mine" {
	    # ns_set put $bind_vars user_selection $user_selection
	    # lappend criteria "a.owner_id=:user_id"
	}
	"all" - "direct_reports"  {
	    ns_set put $bind_vars user_selection $user_selection
	}
    }
}

if { ![empty_string_p $absence_type_id] &&  $absence_type_id != -1 } {
     #ns_set put $bind_vars absence_type_id $absence_type_id
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

set perm_clause "and owner_id = :user_id"
if {$view_absences_all_p || "mine" == $user_selection } {
    set perm_clause ""
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
	im_user_absences a,
        cc_users cc
where
        cc.member_state = 'approved'
	and a.owner_id = cc.object_id
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
        {user_selection:text(select),optional {label "[_ intranet-timesheet2.Show_Users]"} {options $user_selection_types }}
        {timescale:text(select),optional {label "[_ intranet-timesheet2.Timescale]"} {options $timescale_type_list }}
	{start_date:text(text) {label "[_ intranet-timesheet2.Start_Date]"} {html {size 10}} {value "$start_date"} {after_html {<input type="button" style="height:23px; width:23px; background: url('/resources/acs-templating/calendar.gif');" onclick ="return showCalendar('start_date', 'y-m-d');" >}}}
	{end_date:text(text) {label "[_ intranet-timesheet2.End_Date]"} {html {size 10}} {value "$end_date"} {after_html {<input type="button" style="height:23px; width:23px; background: url('/resources/acs-templating/calendar.gif');" onclick ="return showCalendar('end_date', 'y-m-d');" >}}}
    }

template::element::set_value $form_id start_date $start_date
template::element::set_value $form_id end_date $end_date
template::element::set_value $form_id timescale $timescale

eval [template::adp_compile -string {<formtemplate style="tiny-plain-po" id="absence_filter"></formtemplate>}]
set filter_html $__adp_output

# ---------------------------------------------------------------
# Create Links from Menus 
# ---------------------------------------------------------------
set for_user_id ""

if {[string is integer $user_selection] && $add_absences_for_group_p && $user_selection != $user_id} { 
	# Log for other user "than current user" requires 
	set for_user_id $user_selection
} else {
	set for_user_id $current_user_id 
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
set index -1
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
set absence_cube_html ""
set absence_cube_html [im_absence_cube \
			   -absence_status_id $status_id \
			   -absence_type_id $org_absence_type_id \
			   -user_selection $user_selection \
			   -timescale $timescale \
			   -report_start_date $org_start_date \
			   -report_end_date $org_end_date \
			   -user_id_from_search $user_id_from_search \
]

