# /packages/intranet-timesheet2/www/hours/send_pr_info-2.tcl
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
    Purpose: Send project status info by e-mail (action)

    @author jruiz@competitiveness.com
    @creation-date May 2003
} {
    from
    to
    projects:multiple,notnull
}

set page_title "Send project report confirmation"
set context_bar [im_context_bar [list /intranet/ "Your workspace"] [list "/intranet/dedication_days_pr?report_pr_p=y" "Dedication days report"] "Send project report confirmation"]

foreach project_id $projects {
    set sql_query "select pr.group_id as project_id, \
	                  ug.short_name as project_name \
			  from IM_PROJECTS pr, USER_GROUPS ug \
			  where pr.group_id = ug.group_id \
			  and pr.group_id = :project_id \
			  order by project_name"
    
    if { [db_0or1row get_project_data $sql_query] } {
	append mail_content "
<table border=0 cellpadding=3 cellspacing=0>
  <tr>
    <td colspan=2>&nbsp;</td>
    <td class=titlerow colspan=4 align=center>DAYS</td>
    <td colspan=1>&nbsp;</td>
    <td class=titlerow colspan=4 align=center>AMOUNTS</td>
  </tr>
  <tr>
    <td class=titlerow>Case</td>
    <td class=titlerow>Employee</td>
    <td class=titlerow align=center>Budget</td>
    <td class=titlerow align=center>Real</td>
    <td class=titlerow align=center><font color=red>Deviation<font></td>
    <td class=titlerow align=center>%</td>
    <td class=titlerow>&nbsp;</td>
    <td class=titlerow align=center>Budget</td>
    <td class=titlerow align=center>Real</td>
    <td class=titlerow align=center><font color=red>Deviation</font></td>
    <td class=titlerow align=center>%</td>
  </tr>"

	set sql_query "select rownum, employee_id, emp_name from \
                     (select rownum, \
                             u.user_id as employee_id, \
                             SUBSTR(u.email, 0, INSTR(u.email,'@')-1) as emp_name \
                      from USERS u, USER_GROUP_MAP ugm \
                      where ugm.group_id = :project_id \
                      and u.user_id = ugm.user_id \
                      order by emp_name)"

	set sum_days "0"
	set sum_real_days "0"
	set sum_cost "0"
	set sum_real_cost "0"

	db_foreach get_user_projects $sql_query {
	    append page_body "<tr>"
	    if { $rownum == "1" } {
		append mail_content "<tr><td class=row[expr $rownum%2]><b>$project_name</b></td>"
	    } else {
		append mail_content "<tr><td class=row[expr $rownum%2]>&nbsp;</td>"
	    }
	    
	    set days [db_string g_days "select TO_CHAR(NVL(field_value,0),'999990D9') \
                                    from USER_GROUP_MEMBER_FIELD_MAP \
                                    where group_id=:project_id \
                                    and user_id=:employee_id \
                                    and field_name='estimation_days'" -default "0.0"]
	    set day_cost [db_string g_cost "select TO_CHAR(NVL(field_value,0),'999990') \
                                    from USER_GROUP_MEMBER_FIELD_MAP \
                                    where group_id=:project_id \
                                    and user_id=:employee_id \
                                    and field_name='cost_per_day'" -default "0"]
	    set real_days [db_string g_r_days "select TO_CHAR(NVL(SUM(hours)/10,0),'999990D9') \
                                           from IM_HOURS \
                                           where on_what_id=:project_id \
                                           and user_id=:employee_id" -default "0.0"]

	    set days_diff [expr $days - $real_days]
	    set cost [format "%0.0f" [expr $days * $day_cost]]
	    set real_cost [format "%0.0f" [expr $real_days * $day_cost]]
	    set cost_diff [format "%0.0f" [expr $cost - $real_cost]]

	    if { $days_diff < 0 } {
		set days_diff_color " style=\"color:red\" "
	    } else {
		set days_diff_color " style=\"color:blue\" "
	    }
	    if { $cost_diff < 0 } {
		set cost_diff_color " style=\"color:red\" "
		set sendmail_p true
	    } else {
		set cost_diff_color " style=\"color:blue\" "
	    }
	    if { $days == "0" } {
		set per_days "NaN"
	    } else {
		set per_days [format "%0.2f" [expr [expr $days_diff / $days] * 100]]%
	    }
	    if { $cost == "0" } {
		set per_cost "NaN"
	    } else {
		set per_cost [format "%0.2f" [expr [expr $cost_diff.0 / $cost] * 100]]%
	    }
	    
	    append mail_content "
	    <td class=row[expr $rownum%2]>$emp_name</td>
	    <td class=row[expr $rownum%2] align=right>$days</td>
	    <td class=row[expr $rownum%2] align=right>$real_days</td>
	    <td class=row[expr $rownum%2] align=right $days_diff_color>$days_diff</td>
	    <td class=row[expr $rownum%2] align=right $days_diff_color>$per_days</td>
	    <td class=row[expr $rownum%2]>&nbsp;</td>
	    <td class=row[expr $rownum%2] align=right>$cost</td>
	    <td class=row[expr $rownum%2] align=right>$real_cost</td>
	    <td class=row[expr $rownum%2] align=right $cost_diff_color>$cost_diff</td>
	    <td class=row[expr $rownum%2] align=right $cost_diff_color>$per_cost</td>
	    </tr>"
	    set sum_days [expr $sum_days + $days]
	    set sum_cost [expr $sum_cost + $cost]
	    set sum_real_days [expr $sum_real_days + $real_days]
	    set sum_real_cost [expr $sum_real_cost + $real_cost]
	}
	
	set sum_days_diff [expr $sum_days - $sum_real_days]
	set sum_cost_diff [expr $sum_cost - $sum_real_cost]
	if { $sum_days_diff < 0 } {
            set sum_days_color " style=\"color:red\" "
	} else {
            set sum_days_color ""
	}
	if { $sum_cost_diff < 0 } {
            set sum_cost_color " style=\"color:red\" "
	} else {
            set sum_cost_color ""
	}
	if { $sum_days == "0" } {
            set per_sum_days "NaN"
	} else {
            set per_sum_days [format "%0.2f" [expr [expr $sum_days_diff / $sum_days] * 100]]%
	}
	if { $sum_cost == "0" } {
            set per_sum_cost "NaN"
	} else {
            set per_sum_cost [format "%0.2f" [expr [expr $sum_cost_diff.0 / $sum_cost] * 100]]%
	}
	
	append mail_content "
	<tr>
	<td class=titlerow>&nbsp;</td>
	<td class=titlerow><b><i>Total</b></i></td>
	<td class=titlerow align=right><i>$sum_days</i></td>
	<td class=titlerow align=right><i>$sum_real_days</i></td>
	<td class=titlerow align=right $sum_days_color><i>$sum_days_diff</i></td>
	<td class=titlerow align=right $sum_days_color><i>$per_sum_days</i></td>
	<td class=titlerow>&nbsp;</td>
	<td class=titlerow align=right><i>$sum_cost</i></td>
	<td class=titlerow align=right><i>$sum_real_cost</i></td>
	<td class=titlerow align=right $sum_cost_color><i>$sum_cost_diff</i></td>
	<td class=titlerow align=right $sum_cost_color><b>$per_sum_cost</b></td>
	</tr>
	<tr>    <td colspan=6>[im_pushbar 1 2]</td>    </tr>
	</table>"
	
    }
}

set mail_html "
<html>
<head>
<title>Automatic email from Competitiveness Intranet</title>
[im_stylesheet]
</head>
<body>
<p><b>
Dear consultant,
<br>
<br>
Here you have a report of some Competitiveness projects:</b>
</p>
$mail_content
<br>
<br>
<b>Best regards,
<br>
<br>
Competitiveness</b>
</body></html>
"

##### Create email headers
#
set myheaders [ns_set create extraheaders]
ns_set cput $myheaders "MIME-Version" "1.0"
ns_set cput $myheaders "Content-Type" "text/html; charset=\"us-ascii\""

set subject "\[cIntranet\] Projects budget details."

if [ catch {
    ns_sendmail $to $from $subject $mail_html $myheaders
} errmsg ] {
    set page_body "<li>There was an error sending the email:<br><code>$errmsg</code> \n"
    ns_log Notice "\n-------------> Error in 'send_pr_info-2.tcl' : $errmsg \n"
} else {
    set page_body "<li>The email have been sent to '$to'."
}

doc_return  200 text/html [im_return_template]