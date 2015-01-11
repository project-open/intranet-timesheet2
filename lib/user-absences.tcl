ad_page_contract {

    user-absences.tcl
    @author malte sussdorff malte.sussdorff@cognovis.de
    @date 2013-01-13
}

set user_id [ad_maybe_redirect_for_registration]
set admin_p [im_is_user_site_wide_or_intranet_admin $user_id]
set hr_p [im_user_is_hr_p $user_id]
set view_name "absence_list_home" 
set name_order [parameter::get -package_id [apm_package_id_from_key intranet-core] -parameter "NameOrder" -default 1]
set date_format "YYYY-MM-DD"
set user_name [im_name_from_user_id $user_id]
set page_title "[lang::message::lookup "" intranet-timesheet2.Absences_for_user "Absences for %user_name%"]"

# Check permissions. "See details" is an additional check for
# critical information
# im_company_permissions $user_id $company_id view read write admin

im_absence_component__user_selection \
    -where_clauseVar where_clause \
    -user_selection $user_id_from_search \
    -hide_colors_pVar hide_colors_p


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
# 5. Generate SQL Query
# ---------------------------------------------------------------

# Now let's generate the sql query
set criteria [list]

set bind_vars [ns_set create]

lappend criteria "a.owner_id=:user_id_from_search"
set start_date [db_string last_3m_start_date "select now()::date -31"]
set end_date [db_string last_3m_start_date "select now()::date +180"]

set org_start_date $start_date

# Limit to start-date and end-date
if {"" != $start_date} { lappend criteria "a.end_date::date >= :start_date" }
if {"" != $end_date} { lappend criteria "a.start_date::date <= :end_date" }

set order_by_clause "order by start_date"


set where_clause [join $criteria " and\n	    "]
if { ![empty_string_p $where_clause] } {
    set where_clause " and $where_clause"
}

set perm_clause ""

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

set selection "$sql $order_by_clause"


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
    append table_header_html "  <td class=rowtitle><a href=\"${url}order_by=[ns_urlencode $col]\">$col_txt</a>$wrench_html</td>\n"
    incr ctr
}
append table_header_html "</tr>\n"


# ---------------------------------------------------------------
# 8. Format the Result Data
# ---------------------------------------------------------------

set table_body_html ""
set bgcolor(0) " class=roweven "
set bgcolor(1) " class=rowodd "
set user_link ""
set absences_url [parameter::get -package_id [apm_package_id_from_key intranet-timesheet2] -parameter "AbsenceURL" -default "/intranet-timesheet2/absences"]

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

}

# Links to add absences
set admin_html [im_menu_ul_list -package_key "intranet-timesheet2" "timesheet2_absences" "{user_id_from_search} {$user_id_from_search} {return_url} {$return_url}"]
