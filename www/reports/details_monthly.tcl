# /packages/intranet-timesheet2/www/reports/details_monthly.tcl
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
    Show the details of all hours logged by all employees in a single
    month.
    
    @author frank.bergmann@project-open.com
} {
    { year "" }
    { month "" }
}

set user_id [ad_maybe_redirect_for_registration]

if {"" == $year} { set year [db_string current_year "select to_char(sysdate, 'yyyy') from dual"] }
if {"" == $month} { set month [db_string current_month "select to_char(sysdate, 'mm') from dual"] }

set page_title "Hour Details for $month/$year"
set context_bar [im_context_bar $page_title]


# Create a filter for year/month
set filter_html "
<form method=POST action=details_monthly>
<table border=0 cellpadding=0 cellspacing=0>
  <tr> 
    <td colspan='2' class=rowtitle align=center>
      Select Month
    </td>
  </tr>
  <tr class=roweven> 
    <td>Year</td>
    <td>
      <select name=year value='$year'>
<option value=2002>2002</option>
<option value=2003>2003</option>
<option value=2004>2004</option>
<option value=2005>2005</option>
<option value=2006>2006</option>
      </select>
    </td>
  </tr>
  <tr class=rowodd>
    <td>Month</td>
    <td>
      <select name=month value='$month'>
<option value=01>January</option>
<option value=02>February</option>
<option value=03>March</option>
<option value=04>April</option>
<option value=05>May</option>
<option value=06>June</option>
<option value=07>July</option>
<option value=08>August</option>
<option value=09>September</option>
<option value=10>October</option>
<option value=11>November</option>
<option value=12>December</option>
      </select>
    </td>
  </tr>
  <tr>
    <td>&nbsp;</td>
    <td><input type=submit></td>
  </tr>
</table>
</form>\n"

set report_html ""
if {"" != $year && "" != $month } {
    # Run the report

    set sql "
select 
	h.*,
	to_char(h.day) as day_formatted,
	p.project_id,
	p.project_name,
	im_name_from_user_id(h.user_id) as user_name
from
	im_hours h,
	im_projects p
where
	h.project_id = p.project_id
	and to_char(h.day, 'yyyy') = :year
	and to_char(h.day, 'mm') = :month
"

    set report_html "
<table border=0 cellpadding=1 cellspacing=1>
  <tr class=rowtitle>
    <td class=rowtitle align=center>Date</td>
    <td class=rowtitle align=center>Hours</td>
    <td class=rowtitle align=center>User</td>
    <td class=rowtitle align=center>Project</td>
    <td class=rowtitle align=center>Note</td>
  </tr>
"
    db_foreach hour_details_monthly $sql {

	append report_html "
  <tr>
    <td>$day_formatted</td>
    <td>$hours</td>
    <td><A href=/intranet/users/view?user_id=$user_id>$user_name</a></td>
    <td><A href=/intranet/projects/view?project_id=$project_id>$project_name</a></td>
    <td>$note</td>
  </tr>\n"
    }

    append report_html "
</table>
"

}


set page_body "
$filter_html
$report_html
" 

doc_return  200 text/html [im_return_template]
