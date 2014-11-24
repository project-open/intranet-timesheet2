# { filter_status_id:integer "" }
# { start_idx:integer 0 }
# { order_by "User" }
# { how_many "" }
# { absence_type_id:integer "5000" }
# { user_selection "mine" }
# { timescale "future" }
# { view_name "absence_list_home" }
# { filter_start_date "" }
# { user_id_from_search "" }
# { cost_center_id:integer "" }
# { project_id ""}

set page_title "[lang::message::lookup "" intranet-timesheet2.Absences_for_user "Absences for $user_name"]"

if {$hide_colors_p} {
    # Show only approved and requested
    set absence_status_id [list [im_user_absence_status_active],[im_user_absence_status_requested]]
} else {
    if { $filter_status_id ne {} } {
        set absence_status_id $filter_status_id
    } else {
        set absence_status_id [im_sub_categories [im_user_absence_status_active]]
    }
}

if { $user_selection_type eq {project} } {
    set user_selection_id $project_id
} elseif { $user_selection_type eq {user} } {
    set user_selection_id $user_id
} elseif { $user_selection_type eq {cost_center} } {
    set user_selection_id $cost_center_id
} elseif { [string is integer -strict $user_selection_type] } {
    set user_selection_id $user_selection_type
    set user_selection_type "user"
} elseif { $user_selection_type eq {mine}} {
    set user_selection_id [ad_get_user_id]
} elseif { $user_selection_type eq {all}} {
    set user_selection_id [ad_get_user_id]
} else {
    error "user_selection_type=$user_selection_type and user_selection_id does not exist"
}


# ---------------------------------------------------------------
# 5. Generate SQL Query
# ---------------------------------------------------------------

set where_clause ""

im_absence_component__absence_criteria \
    -where_clauseVar where_clause \
    -absence_type_id $absence_type_id \
    -absence_status_id $absence_status_id

im_absence_component__user_selection_criteria \
    -where_clauseVar where_clause \
    -user_selection_id $user_selection_id \
    -user_selection_type $user_selection_type

im_absence_component__timescale_criteria \
    -where_clauseVar where_clause \
    -timescale_date $timescale_date
    -timescale $timescale

set order_by_clause [im_absence_component__order_by_clause $order_by]


set sql "
    select
	a.*,
        to_char(start_date,'YYYY-MM-DD') as start_date2,
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
    $absence_status_sql
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



#ad_return_complaint 1 "<pre>$selection :: $user_selection</pre>"

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

    set duration_days [im_absence_calculate_absence_days -absence_id $absence_id]

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


