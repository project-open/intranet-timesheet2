# /packages/intranet-core/www/intranet/companies/index.tcl
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

    @param absence_type_id if specified, limits view to absences of this type
    @param user_selection  if specified, limits view to absences to mine or all
    @param timescale       if specified, limits view to absences of this time slice
    @param order_by  Specifies order for the table

    @author mbryzek@arsdigita.com
    @author Frank Bergmann (frank.bergmann@project-open.com)
    @author Alwin Egger (alwin.egger@gmx.net)
} {
    { status_id:integer "" }
    { start_idx:integer 0 }
    { order_by "User" }
    { how_many "" }
    { absence_type_id:integer "-1" }
    { user_selection "everyones" }
    { timescale "all" }
    { view_name "absence_list_home" }
}


# ---------------------------------------------------------------
# 2. Defaults & Security
# ---------------------------------------------------------------

set user_id [ad_maybe_redirect_for_registration]
set subsite_id [ad_conn subsite_id]
set page_title "[_ intranet-timesheet2.Absences]"
set context_bar [im_context_bar $page_title]
set page_focus "im_header_form.keywords"
set site_url "/intranet-timesheet/absences"
set return_url "$site_url/index"

set user_view_page "/intranet/users/view"
set absence_view_page "$site_url/absences/view"

set user_selection_types [list "all" "All" "mine" "Mine"]
set timescale_types [list "all" "All" "today" "Today" "next_1m" "Next_Month" "past" "Past" "future" "Future" "last_3m" "Last_3_months"]

if { ![exists_and_not_null absence_type_id] } {
    # Default type is "all" == -1 - select the id once and memoize it
    set absence_type_id -1;
}

set end_idx [expr $start_idx + $how_many - 1]
set date_format "YYYY-MM-DD"

# ---------------------------------------------------------------
# 3. Define Table Columns
# ---------------------------------------------------------------

# Define the column headers and column contents that
# we want to show:
#
set view_id [db_string get_view_id "select view_id from im_views where view_name=:view_name"]
set column_headers [list]
set column_vars [list]

set column_sql "
select
        column_name,
        column_render_tcl,
        visible_for
from
        im_view_columns
where
        view_id=:view_id
        and group_id is null
order by
        sort_order"

db_foreach column_list_sql $column_sql {
    if {$visible_for == "" || [eval $visible_for]} {
        lappend column_headers "$column_name"
        lappend column_vars "$column_render_tcl"
    }
}

# ---------------------------------------------------------------
# 4. Define Filter Categories
# ---------------------------------------------------------------

# absences_types

set absences_types [im_memoize_list select_absences_types "select absence_type_id, absence_type from im_absence_types order by lower(ABSENCE_TYPE)"]
set absences_types [linsert $absences_types 0 -1 "[_ intranet-timesheet2.All]"]

# ---------------------------------------------------------------
# 5. Generate SQL Query
# ---------------------------------------------------------------

# Now let's generate the sql query
set criteria [list]

set bind_vars [ns_set create]
if { ![empty_string_p $user_selection] } {
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
     lappend criteria "a.absence_type=:absence_type_id"
}

switch $timescale {
    "all" { }
    "today" { lappend criteria "a.start_date = '[db_string get_today "select sysdate from dual"]'" }
    "next_1m" { lappend criteria "a.start_date < '[db_string get_next_month "select add_months(sysdate,1) from dual"]' and a.start_date >= '[db_string get_today "select sysdate from dual"]'" }
    "past" { lappend criteria "a.start_date < '[db_string get_today "select sysdate from dual"]'" }
    "future" { lappend criteria "a.start_date > '[db_string get_today "select sysdate from dual"]'" }
    "last_3m" { lappend criteria "a.start_date > '[db_string get_3_months_ago "select add_months(sysdate,-3) from dual"]' and a.start_date < '[db_string get_today "select sysdate from dual"]'" }
}

set order_by_clause ""
switch $order_by {
    "User" { set order_by_clause "order by owner_name, upper(start_date)" }
    "Date" { set order_by_clause "order by upper(start_date), owner_name" }
    "Type" { set order_by_clause "order by upper(absence_type_name), owner_name" }
}

set where_clause [join $criteria " and\n            "]
if { ![empty_string_p $where_clause] } {
    set where_clause " and $where_clause"
}

set sql "
select
        a.absence_id,
        a.owner_id,
        substring(a.description from 1 for 40) as description,
        substring(a.contact_info from 1 for 40) as contact_info,
        to_char(a.start_date, :date_format) as start_date,
        to_char(a.end_date, :date_format) as end_date,
        im_name_from_user_id(a.owner_id) as owner_name,
        im_category_from_id(a.absence_type_id) as absence_type
from
        im_user_absences a
where
        1=1 $where_clause
"

# ---------------------------------------------------------------
# 5a. Limit the SQL query to MAX rows and provide << and >>
# ---------------------------------------------------------------

#TODO all this

# Limit the search results to N data sets only
# to be able to manage large sites

set limited_query [im_select_row_range $sql $start_idx $end_idx]
# We can't get around counting in advance if we want to be able to
# sort inside the table on the page for only those users in the
# query results
set total_in_limited [db_string projects_total_in_limited "
   select count(*)
   from
      im_user_absences a
   where
      1=1
      $where_clause
   "]
set selection "$sql $order_by_clause"

#    set selection "select z.* from ($limited_query) z $order_by_clause"


ns_log Notice $selection

# ---------------------------------------------------------------
# 6. Format the Filter
# ---------------------------------------------------------------

set filter_html "
<form method=get action='$return_url' name=filter_form>
[export_form_vars start_idx order_by how_many view_name]
<table border=0 cellpadding=0 cellspacing=0>
<tr>
  <td colspan='2' class=rowtitle align=center>
[_ intranet-timesheet2.Filter_Absences]
  </td>
</tr>
<tr>
  <td valign=top>[_ intranet-timesheet2.Absence_Type] </td>
<td valign=top>[im_select absence_type_id $absences_types ""]</td>
</tr>
<tr>
  <td valign=top>[_ intranet-timesheet2.Display_Users] </td>
<td valign=top>[im_select user_selection $user_selection_types ""]</td>
</tr>
<tr>
  <td valign=top>[_ intranet-timesheet2.Timescale] </td>
  <td valign=top>
[im_select timescale $timescale_types ""]
    <input type=submit value='[_ intranet-timesheet2.Go]' name=submit>
  </td>
</tr>
</table>
</form>"


# ----------------------------------------------------------
# Do we have to show administration links?

set admin_html "<li><a href=$site_url/new>[_ intranet-timesheet2.Add_a_new_Absence]</a>\n"

if {"" != $admin_html} {
    set absence_filter_html "

<table border=0 cellpadding=0 cellspacing=0>
<tr>
  <td> <!-- TD for the left hand filter HTML -->
    $filter_html
  </td> <!-- end of left hand filter TD -->
  <td>&nbsp;</td>
  <td valign=top>
    <table border=0 cellpadding=0 cellspacing=0>
    <tr>
      <td class=rowtitle align=center>
        [_ intranet-timesheet2.Admin_Absences]
      </td>
    </tr>
    <tr>
      <td>
        $admin_html
      </td>
    </tr>
    </table>
  </td>
</tr>
</table>
"
}


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
foreach col $column_headers {
    regsub -all " " $col "_" col_key
    if { [string equal $order_by $col] } {
        append table_header_html "  <td class=rowtitle>[_ intranet-timesheet2.$col_key]</td>\n"
    } else {
        append table_header_html "  <td class=rowtitle><a href=\"${url}order_by=[ns_urlencode $col]\">[_ intranet-timesheet2.$col_key]</a></td>\n"
    }
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
db_foreach projects_info_query $selection {
    #Append together a line of data based on the "column_vars" parameter list
    append table_body_html "<tr$bgcolor([expr $ctr % 2])>\n"
    foreach column_var $column_vars {
        append table_body_html "\t<td valign=top>"
#	regsub -all "\"" $column_var "" column_var
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
# 10. Join all parts together
# ---------------------------------------------------------------

db_release_unused_handles
