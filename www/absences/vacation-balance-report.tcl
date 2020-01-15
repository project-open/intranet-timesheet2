# /packages/intranet-timesheet2/www/absences/vacation-balance-report.tcl
#
# Copyright (c) 2003-2019 ]project-open[
#
# All rights reserved. 
# Please see http://www.project-open.com/ for licensing.

ad_page_contract {
    Lists vacation balance per user
} {
    { department_id "" }
    { include_users_without_department_p "1" }
    { level_of_detail:integer 2 }
    { output_format "html" }
    { number_locale "" }
}

# ------------------------------------------------------------
# Security
#
set menu_label "vacation-balance-report"
set current_user_id [auth::require_login]
set read_p [db_string report_perms "select im_object_permission_p(m.menu_id, :current_user_id, 'read') from im_menus m where m.label = :menu_label" -default 'f']

# For testing - set manually
set read_p "t"

if {"t" ne $read_p } {
    set message "You don't have the necessary permissions to view this page"
    ad_return_complaint 1 "<li>$message"
    ad_script_abort
}

if {"" eq $include_users_without_department_p} { set include_users_without_department_p 0 }


set current_year_date [db_string current_year "select date_trunc('year', now())::date"]
set last_year_date [db_string current_year "select date_trunc('year', now()::date - 365)::date"]
set current_year_year [string range $current_year_date 0 3]
set last_year_year [string range $last_year_date 0 3]
set january_p [expr "$current_year_year-01" eq [string range $current_year_date 0 6]]
#ad_return_complaint 1 "cur=$current_year_year, last=$last_year_year, jan_p=$january_p"


#set january_p 0

# ------------------------------------------------------------
# Check Parameters
#

# Maxlevel is 3. 
if {$level_of_detail > 3} { set level_of_detail 3 }

# Default is user locale
if {"" == $number_locale} { set number_locale [lang::user::locale] }


# ------------------------------------------------------------
# Page Title, Bread Crums and Help
#
set page_title [lang::message::lookup "" intranet-reporting.HR_Vacation_Balance "HR Vacation Balance"]
set context_bar [im_context_bar $page_title]
set help_text "
	<strong>$page_title:</strong><br>
	[lang::message::lookup "" intranet-reporting.HR_Vacation_Balance_help "
	Shows the vacation status of all employees in the company.<br>
	The report only shows users in group 'Employees', who are <br>
	'active' (not deleted or disabled) and belong to a proper department.
"]"


append help_text "
	<br>&nbsp;<br>
	During January of a new year, the report will allow HR staff to <br>
	update the vacation balance of users from the previous year to the<br>
	current year.
"


# ------------------------------------------------------------
# Default Values and Constants
#
set rowclass(0) "roweven"
set rowclass(1) "rowodd"

set currency_format "999,999,999.09"
set percentage_format "90.9"
set date_format "YYYY-MM-DD"

# Set URLs on how to get to other parts of the system for convenience.
set company_url "/intranet/companies/view?company_id="
set project_url "/intranet/projects/view?project_id="
set department_url "/intranet-cost/cost-centers/new?form_mode=display&cost_center_id="
set vacation_url "/intranet-reporting/new?form_mode=display&vacation_id="
set user_url "/intranet/users/view?user_id="
set this_url "[export_vars -base "/intranet-timesheet2/absences/vacation-balance-report" {} ]?"

# Level of Details
# Determines the LoD of the grouping to be displayed
#
set levels [list \
    1 [lang::message::lookup "" intranet-reporting.Vacation_Balance_per_Department "Vacation Balance per Department"] \
    2 [lang::message::lookup "" intranet-reporting.All_Details "All Details"] \
]

set include_users_without_department_checked ""
if {$include_users_without_department_p} { 
   set include_users_without_department_checked "checked"
}

# ad_return_complaint 1 "include_users_without_department_p=$include_users_without_department_p, $include_users_without_department_checked"



# ------------------------------------------------------------
# Report SQL
#

set cc_sql ""
if {"" != $department_id && 0 != $department_id} {
    set cc_sql "and e.department_id in (:department_id)\n"
}

if {$include_users_without_department_p} {
   set include_users_without_department_sql ""
} else {
   set include_users_without_department_sql "and e.department_id is not null"
}


set report_sql "
	select 
	       department_id,
	       cost_center_code as department_code,
	       cost_center_name as department_name,
	       user_id,
	       user_name,
	       vacation_balance_from_last_year,
	       vacation_balance_year,
	       vacation_days_per_year,
	       vacation_days_taken,
	       vacation_days_taken_last_year,
	       vacation_balance_from_last_year + vacation_days_per_year - vacation_days_taken as vacation_left_this_year
	from (
	       select u.user_id,
	       	      coalesce(e.department_id, 0) as department_id,
		      dept.tree_sortkey,
		      coalesce(dept.cost_center_code, 'undef') as cost_center_code,
		      coalesce(dept.cost_center_name, 'undefined') as cost_center_name,
		      im_name_from_user_id(u.user_id) as user_name,
		      e.vacation_days_per_year,
		      coalesce(e.vacation_balance,0.0) as vacation_balance_from_last_year,
		      to_char(e.vacation_balance_year, 'YYYY-MM') as vacation_balance_year,

		      coalesce((select sum(duration_days)
			      from    im_user_absences a
			      where   a.owner_id = e.employee_id and
				      a.start_date < date_trunc('year', now())::date + 0 and
				      a.end_date >= date_trunc('year', now())::date - 365 and
				      a.absence_type_id in (select * from im_sub_categories([im_user_absence_type_vacation])) and
				      a.absence_status_id not in ([im_user_absence_status_deleted], [im_user_absence_status_rejected])
		       ),0.0) as vacation_days_taken_last_year,

		      coalesce((select sum(duration_days)
			      from    im_user_absences a
			      where   a.owner_id = e.employee_id and
				      a.start_date < date_trunc('year', now())::date +365 and
				      a.end_date >= date_trunc('year', now())::date and
				      a.absence_type_id in (select * from im_sub_categories([im_user_absence_type_vacation])) and
				      a.absence_status_id not in ([im_user_absence_status_deleted], [im_user_absence_status_rejected])
		       ),0.0) as vacation_days_taken

		from   cc_users u,
		       persons pe,
		       im_employees e
		       LEFT OUTER JOIN im_cost_centers dept ON (e.department_id = dept.cost_center_id)
		where  u.user_id = e.employee_id and
		       u.user_id = pe.person_id and
		       u.member_state = 'approved'
		       and e.employee_id in (
		       		select	member_id from	group_distinct_member_map
				where	group_id in (select group_id from groups where group_name = 'Employees')
		       )
		       $include_users_without_department_sql
		       $cc_sql
		) t
	order by
		tree_sortkey,
		user_name
"


# ------------------------------------------------------------
# Report Definition
#

# ad_return_complaint 1 $last_year_year

# Global Header
set header0 [list \
	"Department" \
	"User" \
	"Vacation days<br> from last year" \
	"... from" \
	"Vacation days<br> per year" \
	"Vacation days<br> taken in $current_year_year" \
	"Vacation days<br> left in $current_year_year" \
]

if {$january_p} {
    lappend header0 "Vacation days<br> taken in $last_year_year"
    lappend header0 "Update 'Vacation days from last year' to new value"
}


# Main content line
set user_header_vars {
    "<a href=$department_url$department_id target=_>$department_code</a>"
    "<a href=$user_url$user_id target=_>$user_name</a>"
    "#align=right $vacation_balance_from_last_year_pretty"
    "#align=right $vacation_balance_year"
    "#align=right $vacation_days_per_year_pretty"
    "#align=right $vacation_days_taken_pretty"
    "#align=right $vacation_left_this_year_pretty"
}

if {$january_p} {
    lappend user_header_vars "#align=right \$vacation_days_taken_last_year_pretty"
    set balance_input "<input type=text name=vacation_balance.\$user_id size=4 value='\$new_vacation_balance'>"
    set balance_year_input "<input type=text name=vacation_balance_year.\$user_id size=10 value='$current_year_year-01-01'>"
    lappend user_header_vars "#align=right $balance_input at $balance_year_input"
}

set department_header {
	"\#colspan=10 <a href=$this_url&department_id=$department_id&level_of_detail=3
	target=_blank><img src=/intranet/images/plus_9.gif width=9 height=9 border=0></a> 
	<b><a href=$department_url$department_id target=_>$department_name</a></b>"
}

set department_footer {
    "#colspan=3 <b><a href=$department_url$department_id target=_>$department_name</a></b>"
    "#colspan=3 #align=right <b>Average: ($users_per_dept_subtotal Users): [expr round(10.0 * $vacation_left_subtotal / ($users_per_dept_subtotal + 0.0000001)) / 10.0]</b>"
    "#align=right <b>$vacation_left_subtotal_pretty</b>"
}

set footer0 {
    "#colspan=3 &nbsp;"
    "#colspan=3 #align=right <i>Average ($users_total Users): [expr round(10.0 * $vacation_left_total / ($users_total + 0.0000001)) / 10.0]</i>"
    "#align=right <i>$vacation_left_total_pretty</i>"
}

# Disable cost_center for CSV output
# in order to create one homogenous exportable  lst
if {"csv" == $output_format} { set department_header "" }

# The entries in this list include <a HREF=...> tags
# in order to link the entries to the rest of the system (New!)
#
set report_def [list \
    group_by department_id \
    header $department_header \
    content [list \
	group_by user_id \
	header $user_header_vars \
	content {} \
    ] \
    footer $department_footer \
]


# ------------------------------------------------------------
# Counters
#

#
# (Sub-)total Counters
#
set vacation_left_subtotal_counter [list \
	pretty_name "Vacation Left Subtotal" \
	var vacation_left_subtotal \
	reset \$department_id \
	expr "\$vacation_left_this_year+0" \
]

set vacation_left_total_counter [list \
	pretty_name "Vacation Left Total" \
	var vacation_left_total \
	reset 0 \
	expr "\$vacation_left_this_year+0" \
]

set user_per_dept_counter [list \
	pretty_name "Users per Dept" \
	var users_per_dept_subtotal \
	reset \$department_id \
	expr 1 \
]

set user_total_counter [list \
	pretty_name "Users Total" \
	var users_total \
	reset 0 \
	expr 1 \
]

set counters [list \
		  $vacation_left_subtotal_counter \
		  $vacation_left_total_counter \
		  $user_per_dept_counter \
		  $user_total_counter \
]

# Set the values to 0 as default (New!)
set vacation_left_subtotal 0.00
set vacation_left_total 0.00
set vacation_left_subtotal_pretty 0.00
set vacation_left_total_pretty 0.00
set users_total 0
set users_per_dept_subtotal 0


# ------------------------------------------------------------
# Start Formatting the HTML Page Contents
#

im_report_write_http_headers -report_name $menu_label -output_format $output_format

switch $output_format {
    html {
	ns_write "
	[im_header]
	[im_navbar reporting]
	<table cellspacing=0 cellpadding=0 border=0>
	<tr valign=top>
	  <td width='30%'>
		<!-- 'Filters' - Show the Report parameters -->
		<form>
		<table cellspacing=2>
		<tr class=rowtitle>
		  <td class=rowtitle colspan=2 align=center>Filters</td>
		</tr>
		<tr>
		  <td>Level of<br>Details</td>
		  <td>
		    [im_select -translate_p 0 level_of_detail $levels $level_of_detail]
		  </td>
		</tr>

		<tr>
		  <td>[lang::message::lookup "" intranet-core.Department Department]:</td>
		  <td>[im_cost_center_select -include_empty 1 -include_empty_name "All" department_id $department_id]</td>
		</tr>

		<tr>
			<td class=form-label valign=top>[lang::message::lookup "" intranet-reporting.Include_User_Without_Department "Include users without department:"]</td>
			<td class=form-widget valign=top>
			<input type=checkbox name=include_users_without_department_p value='1' $include_users_without_department_checked>
		</td>

		<tr>
		  <td class=form-label>[lang::message::lookup "" intranet-reporting.Output_Format Format]</td>
		  <td class=form-widget>
		    [im_report_output_format_select output_format "" $output_format]
		  </td>
		</tr>

		<tr>
		  <td class=form-label><nobr>[lang::message::lookup "" intranet-reporting.Number_Format "Number Format"]</nobr></td>
		  <td class=form-widget>
		    [im_report_number_locale_select number_locale $number_locale]
		  </td>
		</tr>
		<tr>
		  <td</td>
		  <td><input type=submit value='Submit'></td>
		</tr>
		</table>
		</form>
	  </td>
	  <td align=center>
		<table cellspacing=2 width='90%'>
		<tr>
		  <td>$help_text</td>
		</tr>
		</table>
	  </td>
	</tr>
	</table>
	
	<!-- Here starts the main report table -->
	<form action=/intranet-timesheet2/absences/vacation-balance-report-update-balance.tcl method=POST>
	[export_vars -form {{return_url $this_url}}]
	<table border=0 cellspacing=1 cellpadding=1>
    "
    }
}

set footer_array_list [list]
set last_value_list [list]

im_report_render_row \
    -output_format $output_format \
    -row $header0 \
    -row_class "rowtitle" \
    -cell_class "rowtitle"

set counter 0
set class ""
db_foreach sql $report_sql {
    set class $rowclass([expr {$counter % 2}])
    
    set vacation_balance_from_last_year_pretty [im_report_format_number $vacation_balance_from_last_year $output_format $number_locale]
    set vacation_days_per_year_pretty [im_report_format_number $vacation_days_per_year $output_format $number_locale]
    set vacation_days_taken_pretty [im_report_format_number $vacation_days_taken $output_format $number_locale]
    set vacation_left_this_year_pretty [im_report_format_number $vacation_left_this_year $output_format $number_locale]
    set vacation_days_taken_last_year_pretty [im_report_format_number $vacation_days_taken_last_year $output_format $number_locale]

    set new_vacation_balance [expr round(100.0 * ($vacation_balance_from_last_year + $vacation_days_per_year - $vacation_days_taken_last_year)) / 100.0]

    

    im_report_display_footer \
	-output_format $output_format \
	-group_def $report_def \
	-footer_array_list $footer_array_list \
	-last_value_array_list $last_value_list \
	-level_of_detail $level_of_detail \
	-row_class $class \
	-cell_class $class

    im_report_update_counters -counters $counters

    set vacation_left_subtotal_pretty [im_report_format_number [expr round(100.0 * $vacation_left_subtotal) / 100.0] $output_format $number_locale]
    set vacation_left_total_pretty [im_report_format_number [expr round(100.0 * $vacation_left_total) / 100.0] $output_format $number_locale]

    set last_value_list [im_report_render_header \
			     -output_format $output_format \
			     -group_def $report_def \
			     -last_value_array_list $last_value_list \
			     -level_of_detail $level_of_detail \
			     -row_class $class \
			     -cell_class $class
			]

    set footer_array_list [im_report_render_footer \
			       -output_format $output_format \
			       -group_def $report_def \
			       -last_value_array_list $last_value_list \
			       -level_of_detail $level_of_detail \
			       -row_class $class \
			       -cell_class $class
			  ]

    incr counter
}

im_report_display_footer \
    -output_format $output_format \
    -group_def $report_def \
    -footer_array_list $footer_array_list \
    -last_value_array_list $last_value_list \
    -level_of_detail $level_of_detail \
    -display_all_footers_p 1 \
    -row_class $class \
    -cell_class $class

im_report_render_row \
    -output_format $output_format \
    -row $footer0 \
    -row_class $class \
    -cell_class $class \
    -upvar_level 1


# Write out the HTMl to close the main report table
#
switch $output_format {
    html {
	ns_write "</table>\n"
	ns_write "<input type=submit value='Update vacation balance'>\n"
	ns_write "</form>\n"
	ns_write "<br>&nbsp;<br>"
	ns_write [im_footer]
    }
}

