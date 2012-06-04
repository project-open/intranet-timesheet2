# /packages/intranet-timesheet2/www/hours/week.tcl
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
    Shows the hour a specified user spend working over the course of a week

    @param julian_date day in julian format in the week we're currently viewing. Defaults to sysdate
    @user_id_from_search the user for whom we're viewing hours. Defaults to currently logged in user.
 
    @author Michael Bryzek (mbryzek@arsdigita.com)
    @creation-date January 2000
    @cvs-id week.tcl,v 3.7.2.7 2000/09/22 01:38:38 kevin Exp
   
} {
    { julian_date "" }
    { user_id_from_search:integer "" }
}

if { [empty_string_p $user_id_from_search] } {
    set user_id_from_search [ad_maybe_redirect_for_registration]
}


if { [empty_string_p $julian_date] } {
    set julian_date [db_string sysdate_as_julian "select to_char(sysdate,'J') from dual"]
}

set user_name [db_string user_name "select im_name_from_user_id(:user_id_from_search) from dual"]

db_1row week_select_start_and_end "
select 
	to_char(next_day(to_date( :julian_date, 'J' )-1, 'sat' ),'MM/DD/YYYY' ) AS end_date,
	to_char( next_day(to_date( :julian_date, 'J' )-1, 'sat' )-6,'MM/DD/YYYY' ) AS start_date
from dual"

set sql "
SELECT 
	p.project_id, 
	p.project_name, 
	sum(h.hours) as total
FROM
	im_hours h,
	im_projects p
WHERE
	p.project_id = h.project_id
	AND h.day >= trunc( to_date( :start_date, 'MM/DD/YYYY' ),'Day' )
    	AND h.day < trunc( to_date( :end_date, 'MM/DD/YYYY' ),'Day' ) + 1
    	AND h.user_id = :user_id_from_search
GROUP BY p.project_id, p.project_name
"

set items {}
set grand_total 0

db_foreach hour_select $sql {
    if {"" == $total} { set total 0 }
    set grand_total [expr $grand_total+$total]
    lappend items [list $project_id $project_name $total]
}

set sql "
SELECT
	p.project_id, 
	p.project_name, 
        h.note,
	TO_CHAR( day, 'Dy, MM/DD/YYYY' ) as nice_day
FROM 
	im_hours h, 
	im_projects p
WHERE
	h.project_id = p.project_id
	AND h.day >= trunc( to_date( :start_date, 'MM/DD/YYYY' ),'Day' )
    	AND h.day < trunc( to_date( :end_date, 'MM/DD/YYYY' ),'Day' ) + 1
    	AND h.user_id = :user_id_from_search
ORDER BY lower(p.project_name), day
"

set last_id -1
set pcount 0
set notes "<hr>\n<h2>[_ intranet-timesheet2.Daily_project_notes]</h2>\n"

db_foreach hours_daily_project_notes $sql {
    if {[empty_string_p $note]} {
	set note "<i>[_ intranet-timesheet2.none]</i>"
    }
    if { $last_id != $project_id } {
	set last_id $project_id
	if { $pcount > 0 } {
	    append notes "</ul>\n"
	}
	append notes "<h3>$project_name</h3>\n<ul>\n"
	incr pcount
    }
    append notes "<li><b>$nice_day:</b>&nbsp;$note\n"
}

if { $pcount > 0 } {
    append notes "</ul>\n"
} else {
    set notes ""
}

db_release_unused_handles

set hour_table "[_ intranet-timesheet2.lt_No_hours_for_this_wee]"

if {[llength $items] > 0 } {
    set hour_table "<table cellspacing=1 cellpadding=3>
    <tr bgcolor=#666666>
    <th><font color=#ffffff>[_ intranet-timesheet2.Project]</font></th>
    <th><font color=#ffffff>[_ intranet-timesheet2.Hours]</font></th>
    <th><font color=#ffffff>[_ intranet-timesheet2.Percentage]</font></th>
    </tr>
    "

    foreach row $items {
	set project_id [lindex $row 0]
	set project_name [lindex $row 1]
	set total [lindex $row 2]
	append hour_table "<tr bgcolor=#efefef>
	<td><a href=/intranet/projects/view?[export_url_vars project_id]>
	    $project_name</a></td>
	<td align=right>[format "%0.02f" $total]</td>
	<td align=right>[format "%0.02f%%" \
	    [expr double($total)/$grand_total*100]]</td>
	</tr>
	"
    }

    append hour_table "<tr bgcolor=#aaaaaa>
    	<td><b>[_ intranet-timesheet2.Grand_Total]</b></td>
    	<td align=right><b>[format "%0.02f" $grand_total]</b></td>
    	<td align=right><b>100.00%</b></td>
    	</tr>
    	</table>\n"
}

set page_title "[_ intranet-timesheet2.lt_Weekly_total_by_user_]"
set context_bar [im_context_bar [list index "[_ intranet-timesheet2.Your_hours]"] "[_ intranet-timesheet2.Weekly_hours]"]

set page_body "
$hour_table
$notes
"

#doc_return  200 text/html [im_return_template]

