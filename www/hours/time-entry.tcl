# /packages/intranet-timesheet/www/hours/time-entry.tcl
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


ad_page_contract {
    Weekly time entry form

    @param on_which_table table we're adding hours
    @param on_what_id The row for which we're adding hours
    @param julian_date day in julian format for which we're adding hours
    @return_url Return URL
    @param on_what_id_list A multi list of on_what_id's we've selected
 
	@author Michael Bryzek (mbryzek@arsdigita.com)

	@cvs-id time-entry.tcl,v 3.6.2.10 2000/09/22 01:38:38 kevin Exp
   
} {
    { user_id:integer "" }
    { on_which_table "im_projects" }
    { on_what_id:integer "" }
    { julian_date "" }
    { return_url "" }
    { on_what_id_list:multiple "" }
}


# Pull out the proc that formats one row because we use it in a few places
proc local_im_time_entry_format_row { group_id julian_date { hours "" } { notes "" } } {
    return "
  <td>
<input type=hidden name=\"old_hours.${group_id}.${julian_date}.hours\" [export_form_value hours]>
<input type=hidden name=\"old_hours.${group_id}.${julian_date}.notes\" [export_form_value notes]>
	[_ intranet-timesheet2.Hours_1] &nbsp; <input type=text name=hours.${group_id}.${julian_date}.hours size=5 [export_form_value hours]>
	<br>[_ intranet-timesheet2.Notes]<br><input type=text name=hours.${group_id}.${julian_date}.notes size=15 [export_form_value notes]>
  </td>
"
}

# Break up the big table into multiple smaller ones
set number_rows_per_table 5

set user_id [im_hours_verify_user_id $user_id]

if { [empty_string_p $julian_date] } {
    # Default the julian_date to today
    set julian_date [db_string julian_date_from_daul "select to_char(sysdate,'J') from dual"]
}

# Pull out the user's first and last names for UI purposes
db_1row user_name "
select im_name_from_user_id(user_id) user_name
from   users
where  user_id = :user_id"

# Kind of a hairy query... Basically, we use arithmetic on julian dates to say:
# Take today  minus the number of the day of the week where sunday is 0 and saturday is 6
# and turn that whole thing into a julian date
# Now we can do a query for between the first_day_of_the_week and (first_day_of_the_week + 7)
# Grab the ansi date too
db_1row julian_ansi_date_select "
select to_char(to_date(1 + :julian_date - to_char(to_date(:julian_date,'J'),'d'),'J'),'J') as first_julian_date,
		to_date(to_date(1 + :julian_date - to_char(to_date(:julian_date,'J'),'d'),'J')) as ansi_date
	  from dual" 

set last_julian_date [expr $first_julian_date + 7]

# We need to generate a list of the project ids to which the user
# belongs. We show these in case the user has not logged hours on them
# yet (meaning the between in our query fails)

# We use bind variables here because we will be generating fields on the fly
set bind_vars [ns_set create]
ns_set put $bind_vars julian_date $julian_date
ns_set put $bind_vars user_id $user_id

if { ![empty_string_p $on_what_id] } {
    # only grab the one project that is specified
    set project_id_list [list $on_what_id]

} elseif { [llength $on_what_id_list] > 0 } {
    # The user selected a few projects... use those
    set project_id_list $on_what_id_list

} else {

    # pretty nasty query. Basically, we want all open or future projects 
    # that the user either:
    #	a. belongs to
    #	b. has logged hours on sometime during the select week
    # If this number of projects is greater than 2 * number_rows_per_table, 
    # pick out only the projects on which the user has logged hours during 
    # the last 3 weeks or the future 3 weeks (in case we're logging hours for
    # last week)

    set max_number_of_projects [expr 2 * $number_rows_per_table]

    set project_id_list [db_list project_id_list "
select
	p.project_id 
from
	acs_rels r, 
	im_projects p
where
	r.object_id_two = :user_id
	and r.object_id_one = p.project_id
"]

    set additional_sql "
	and p.project_status_id in (
		select project_status_id
		from im_project_status
		where upper(project_status) in ('OPEN','FUTURE')
	) UNION
		select h.on_what_id
		from im_hours h
		where 
			h.user_id = :user_id
			and h.on_which_table = :on_which_table
			and (h.hours is not null OR h.note is not null)
			and (to_char(h.day,'J') between :first_julian_date and :last_julian_date)
"
	
    if { [llength $project_id_list] > $max_number_of_projects } {
	set hours_id_list [db_list projects_user_logged_hours_for \
		"select h.on_what_id
		  from im_hours h
		 where h.user_id = :user_id
			and h.on_which_table = :on_which_table
			and (h.hours is not null OR h.note is not null)
			and (h.day between to_date(:first_julian_date-21,'J') and to_date(:last_julian_date+21,'J'))"]
	
	if { [llength $hours_id_list] > 0 } {
	    # only set the project_id_list if the user has logged 
	    # hours on at least one project
	    set project_id_list $hours_id_list
	}
    }
}

set sql_clause [im_append_list_to_ns_set $bind_vars group_id_sql $project_id_list]
set limit_to_sql "ug.group_id in ($sql_clause)"

set table_header "<table cellpadding=2 cellspacing=2 border=1>
<tr bgcolor=#dddddd>
  <th>[_ intranet-timesheet2.Project]</th>
"

# Do a select for the header here. Note that we have to do this
# because we're not guaranteed that all the dates will be covered.
# We build up the sql query to do this as few times as possible

set select_clause ""
for { set i $first_julian_date } { $i < $last_julian_date } { incr i } {
    if { ![empty_string_p $select_clause] } {
	append select_clause ",\n	"
    }
    ns_set put $bind_vars pretty_day_$i $i
    append select_clause "to_char(to_date(:pretty_day_$i,'J'),'Day') as pretty_day_$i, to_char(to_date(:pretty_day_$i,'J'),'MM/DD') as day_$i"
}

db_1row week_select_name_and_dates "select $select_clause from dual" -bind $bind_vars

# Now loop through and print the header out
for { set i $first_julian_date } { $i < $last_julian_date } { incr i } {
    append table_header "  <th>[set "pretty_day_$i"] - [set "day_$i"]</th>\n"
}

append table_header "</tr>\n"

# Keep the table_header separate to repeat every $number_rows_per_table rows
set table "$table_header"

# Pull out a list of intranet projects to which the user belongs
set sql "
select
	ug.group_id,
	ug.group_name
from
	user_groups ug, 
	im_projects p
where 
	ug.group_id = p.group_id 
	and $limit_to_sql
order by lower(ug.group_name)
" 

if { [empty_string_p $project_id_list] } {
    # Redirect user to select projects on which to log hours
    ad_returnredirect other-projects?[export_url_vars user_id on_which_table julian_date]
    return
}

set project_id_list [db_list_of_lists project_id_name_list $sql -bind $bind_vars]

# Alternate background colors for the rows in the table to make it
# easier to enter data
set bgcolor(0) " bgcolor=roweven"
set bgcolor(1) " bgcolor=rowodd"

# Maybe someone smarter than me (mbryzek) can figure out to do this
# query without doing the list/list + subquery thing. I just couldn't
# figure out a good way not to miss days or projects.

set ctr 0

foreach pair $project_id_list {
    set group_id [lindex $pair 0]
    set group_name [lindex $pair 1]
    # Break up the table if we hit the specified number of rows for each table
    if { $ctr > 0 && $ctr % $number_rows_per_table == 0 } {
	append table "
</table>
<p>
$table_header
"
    }
    incr ctr
    
    append table "
<tr$bgcolor([expr $ctr % 2])>
  <td><b>$group_name</b></td>
"

	# last_julian_date is actually the last sunday... so we subtract a touch to get the day before
    set sql "select h.hours, h.note, h.billing_rate, to_char(h.day, 'J') as this_julian_date
		from im_hours h
		where h.on_what_id = :group_id
		and h.on_which_table = :on_which_table
		and h.user_id(+) = :user_id
		and to_char(h.day,'J') between :first_julian_date and :last_julian_date-.00001
		order by h.day asc"
	
    set temp_cursor $first_julian_date
    
    db_foreach hours_logged_for_week $sql { 
	while { $temp_cursor < $this_julian_date } {
	    append table [local_im_time_entry_format_row $group_id $temp_cursor]
	    incr temp_cursor
	}
	append table [local_im_time_entry_format_row $group_id $this_julian_date $hours $note]
	incr temp_cursor
    }
    while { $temp_cursor < $last_julian_date } {
	append table [local_im_time_entry_format_row $group_id $temp_cursor]
	incr temp_cursor
    }
    append table "</tr>\n"
}

if { [empty_string_p $on_what_id] } {
	append table "
<tr>
  <td colspan=8 bgcolor=#dddddd align=center>
	<a href=other-projects?[export_url_vars user_id on_which_table julian_date]>[_ intranet-timesheet2.lt_Add_hours_on_other_pr]</A>
  </td>
</tr>
"
}

append table "</table>\n"	

set date_value "[util_AnsiDatetoPrettyDate $ansi_date]"
set page_title "[_ intranet-timesheet2.lt_Hours_for_user_name_W]"
set context_bar [im_context_bar [list index?[export_url_vars on_which_table] "[_ intranet-timesheet2.Hours]"] "[_ intranet-timesheet2.Add_hours]"]

set options [list "<a href=index?[export_ns_set_vars url [list julian_date]]>[_ intranet-timesheet2.lt_Log_hours_for_a_diffe_1]</a>"]

if { ![empty_string_p $return_url] } {
    lappend options "<a href=$return_url>[_ intranet-timesheet2.lt_Go_back_to_where_you_]</a>"
}

set page_body "
<center>\[
[join $options " | "]
\]</center>

<form method=post action=time-entry-2>
[export_form_vars julian_date return_url on_which_table user_id]
<center>
$table

<p><input type=submit value=\" [_ intranet-timesheet2.Add_hours] \">
</form>

</center>
"

doc_return  200 text/html [im_return_template]
