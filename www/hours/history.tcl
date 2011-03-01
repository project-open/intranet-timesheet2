# /packages/intranet-timesheet2/www/hours/history.tcl
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
    Shows a history of hours logged for a project by all employees
    over a period of time (several weeks/months)
 
    @param on_what_id     the project for which we're viewing hours.
    @param from_date      start date of history in format of ad_dateentrywidget (array)
    @param to_date        end date of history in format of ad_dateentrywidget (array)
    @param based          on what basis (hours/week) do we calculate?
    @param interval       which interval shall be viewed per column (day, month, week)
    @param letters        the first letter of the project (for the select-box)

    @author Kolja Lehmann (koljalehmann@uni.de)
    @creation-date August 2000
    @cvs-id history.tcl,v 1.1.2.2 2000/09/05 23:00:02 mbryzek Exp
 
} {
    { on_what_id:integer "" }
    { from_date:array "" }
    { to_date:array "" }
    { based "50" }
    { interval "week" }
    { letters "A" }
}

set form [ns_conn form]
if {[empty_string_p $form]} {
    set form [ns_set new]
}

set from [validate_ad_dateentrywidget "" from_date $form allownull]
if { [empty_string_p $from] } {
    set from [db_string sysdate \
            "select to_char(add_months(sysdate,-3),'YYYY-MM-DD') from dual"]
}

set ending [validate_ad_dateentrywidget "" to_date $form allownull]
if { [empty_string_p $ending] } {
    set ending [db_string sysdate \
            "select to_char(sysdate,'YYYY-MM-DD') from dual"]
}


set columns 3
set colno 0
set project_select "<script language=javascript>
<!--
var names=new Object();
var values=new Object();
"
set count 0
db_foreach "project select-box" "
select 
	group_name, 
	u.group_id as group_id 
from 
	user_groups u, 
	$on_which_table p
where 
	u.group_id=p.group_id
" {
    regsub -all {'} $group_name \\' group_name
    append project_select "
    names\[$count\]='$group_name';
    values\[$count\]='$group_id';"
    incr count
}
# names is an array of project_names, values contains the group_ids
append project_select "
function prj_List() {
    var letter=document.forms\[0\].letters.options\[document.forms\[0\].letters.options.selectedIndex\].value;
    var j=0;
    for (i=document.forms\[0\].on_what_id.length-1;i>=0;i--) {
        document.forms\[0\].on_what_id.options\[i\]=null;
    }	
    for (i=0;i<$count;i++) {
	if (names\[i\].toUpperCase().charAt(0)==letter) {
	    document.forms\[0\].on_what_id.options\[j\]=new Option();
	    document.forms\[0\].on_what_id.options\[j\].text=names\[i\];
	    document.forms\[0\].on_what_id.options\[j\].value=values\[i\];
	    j++;
	}
    }
}

  //-->
</script>
<select name=letters onChange=prj_List()>
<option value=A>[_ intranet-timesheet2.A]<option value=B>[_ intranet-timesheet2.B]<option value=C>[_ intranet-timesheet2.C]<option value=D>[_ intranet-timesheet2.D]<option value=E>[_ intranet-timesheet2.E]<option value=F>[_ intranet-timesheet2.F]<option value=G>[_ intranet-timesheet2.G]<option value=H>[_ intranet-timesheet2.H]<option value=I>[_ intranet-timesheet2.I]<option value=J>[_ intranet-timesheet2.J]option value=K>[_ intranet-timesheet2.K]<option value=L>[_ intranet-timesheet2.L]<option value=M>[_ intranet-timesheet2.M]<option value=N>[_ intranet-timesheet2.N]<option value=O>[_ intranet-timesheet2.O]<option value=P>[_ intranet-timesheet2.P]<option value=Q>[_ intranet-timesheet2.Q]<option value=R>[_ intranet-timesheet2.R]<option value=S>[_ intranet-timesheet2.S]<option value=T>[_ intranet-timesheet2.T]<option value=U>[_ intranet-timesheet2.U]<option value=V>[_ intranet-timesheet2.V]<option value=W>[_ intranet-timesheet2.W]<option value=X>[_ intranet-timesheet2.X]<option value=Y>[_ intranet-timesheet2.Y]<option value=Z><#_Z#>
</select>
<select name=on_what_id>
<option value=\"\"> -- [_ intranet-timesheet2.lt_Please_select_a_proje] --
</select>

"

    
#      if {$on_what_id==$group_id} {
#  	append project_select "<input type=radio name=on_what_id value=$group_id selected>$group_name\n"
#      } else {
#  	append project_select "<input type=radio name=on_what_id value=$group_id>$group_name\n"
#      }
#      incr colno
#      if {[expr $colno % $columns]==0} {
#  	append project_select "<br>"
#      }
#  }
#  append project_select "<br>\n"

set from_date_select [ad_dateentrywidget from_date $from]
set to_date_select   [ad_dateentrywidget to_date $ending]
set based_select "<input type=text name=based value=$based>"
set interval_select "<select name=interval>"
switch $interval {
    day {append interval_select "
    <option value=day selected>[_ intranet-timesheet2.Day]
    <option value=week>[_ intranet-timesheet2.Week]
    <option value=month>[_ intranet-timesheet2.Month]
    </select>\n"}
    week {append interval_select "
    <option value=day>[_ intranet-timesheet2.Day]
    <option value=week selected>[_ intranet-timesheet2.Week]
    <option value=month>[_ intranet-timesheet2.Month]
    </select>\n"}
    month {append interval_select "
    <option value=day>[_ intranet-timesheet2.Day]
    <option value=week>[_ intranet-timesheet2.Week]
    <option value=month selected>[_ intranet-timesheet2.Month]
    </select>\n"}
}

set selection_block "
    <form method=get action=history>
    <table>
    <tr><td valign=top>[_ intranet-timesheet2.For_which_project] <td>$project_select</tr>
    <tr><td>[_ intranet-timesheet2.Starting] <td>$from_date_select</tr>
    <tr><td>[_ intranet-timesheet2.Ending] <td>$to_date_select</tr>
    <tr><td>[_ intranet-timesheet2.Based_on] <td>[_ intranet-timesheet2.lt_based_select_hours_pe]</tr>
    <tr><td>[_ intranet-timesheet2.Show_one] <td>[_ intranet-timesheet2.lt_interval_select_per_c]</tr>
    </table>
    <input type=submit value=\"[_ intranet-timesheet2.View]\">
    </form>"
doc_body_append $selection_block
doc_set_property author "koljalehmann@uni.de"
doc_set_property navbar [list [list index?[export_url_vars on_which_table] "[_ intranet-timesheet2.Your_hours]"] "[_ intranet-timesheet2.Project_History]"]
doc_set_property title "[_ intranet-timesheet2.View_History]"

if {[empty_string_p [ns_conn form]] || [empty_string_p $on_what_id]} {
    return
} else {
    doc_body_append "
<script language=javascript>
<!--
function set_select_boxes() {
    var let=new String(\"$letters\").charCodeAt(0)-new String(\"A\").charCodeAt(0);
    document.forms\[0\].letters.options\[let\].selected=true;
    prj_List();
    for (i=0;i<document.forms\[0\].on_what_id.length;i++) {
	if (document.forms\[0\].on_what_id.options\[i\].value==$on_what_id) {
	    document.forms\[0\].on_what_id.options\[i\].selected=true;
	}
    }
}
set_select_boxes();
  //-->
</script>
"
}
db_1row "get_project_name" "select group_name as project_name from user_groups where group_id=:on_what_id"

set inter_dates {}
set inter_date $from
while {$inter_date<$ending} {
    switch $interval {
	day   {db_1row next_day "
	select to_date(:inter_date,'YYYY-MM-DD') + 1 as inter_date, 
	to_char(to_date(:inter_date,'YYYY-MM-DD'),'DD. Mon YY') as pretty_start, 
	to_char(to_date(:inter_date,'YYYY-MM-DD'),'DD. Mon YY') as pretty_end, 
	1 as days from dual"}
	week  {db_1row next_week "select next_day(:inter_date, 'MONDAY') as inter_date, 
	to_char(to_date(:inter_date,'YYYY-MM-DD'),'DD. Mon YY') as pretty_start, 
	to_char(next_day(:inter_date, 'MONDAY')-1,'DD. Mon YY') as pretty_end,
	7 as days from dual"}
	month {db_1row next_month "select last_day(:inter_date)+1 as inter_date, 
	to_char(to_date(:inter_date,'YYYY-MM-DD'),'DD. Mon YY') as pretty_start, 
	to_char(last_day(:inter_date),'DD. Mon YY') as pretty_end,
	((last_day(:inter_date)+1) - to_date(:inter_date,'YYYY-MM-DD')) as days from dual"}
    }
    if {$inter_date<$ending} {
	lappend inter_dates $inter_date
	set pretty_date($inter_date.start) $pretty_start
	set pretty_date($inter_date.end) $pretty_end
	set interval_length($inter_date) $days
    }
}

set last_date [lindex $inter_dates [expr [llength $inter_dates] - 1]]
db_1row pretty_start_end_time "select to_char(to_date(:last_date,'YYYY-MM-DD'),'DD. Mon YY') as pretty_start,
to_char(to_date(:ending,'YYYY-MM-DD'),'DD. Mon YY') as pretty_end,
(to_date(:ending,'YYYY-MM-DD')-to_date(:last_date,'YYYY-MM-DD')+1) as days from dual"
set pretty_date($ending.start) $pretty_start
set pretty_date($ending.end) $pretty_end
set interval_length($ending) $days
lappend inter_dates $ending

set begin_time $from
set user_id_list {}
foreach end_time $inter_dates {
    db_foreach fill_table_with_hours "
    select sum(hours) as hours, user_id
    from im_hours h
    where 
        upper(h.on_which_table)=upper('$on_which_table') and
        h.on_what_id='$on_what_id' and
        h.day >= to_date('$begin_time','YYYY-MM-DD') and
        h.day < to_date('$end_time','YYYY-MM-DD')
    group by user_id" {
	if {[lsearch -exact $user_id_list $user_id]==-1} {
	    lappend user_id_list $user_id
	}
	set table_data($end_time.$user_id) $hours 
    }
    set begin_time $end_time
}

if {[empty_string_p $user_id_list]} {
    doc_body_append "[_ intranet-timesheet2.lt_No_hours_logged_on_pr]"
    return
}

db_foreach get_employee_names "
	select	im_name_from_user_id(user_id) as employee, 
		user_id 
	from	users
	where	user_id in ([join $user_id_list ", "])
" {
       set employees($user_id) $employee 
}

db_release_unused_handles

doc_body_append "<table border><tr><th>$project_name</th>"

foreach end_time $inter_dates {
    doc_body_append "<td>$pretty_date($end_time.start)-<br>$pretty_date($end_time.end)</th>"
    set colsum($end_time) 0
}
doc_body_append "<th>[_ intranet-timesheet2.Hours]</tr>"

foreach user_id $user_id_list {
    doc_body_append "
      <tr><td>$employees($user_id)"
    set rowsum 0
    foreach end_time $inter_dates {
	doc_body_append "
	    <td align=right>[export_var table_data($end_time.$user_id) "0"]"
	set rowsum [expr $rowsum + [export_var table_data($end_time.$user_id) 0]]
	set colsum($end_time) [expr $colsum($end_time) + [export_var table_data($end_time.$user_id) 0]]
    }
    doc_body_append "<th align=right>$rowsum</tr>"
}

set total 0
doc_body_append "<tr><th>[_ intranet-timesheet2.lt_Full_Time_Equivalents]"
foreach end_time $inter_dates {
    doc_body_append "<th>[format "%4.0f"\
    [expr ($colsum($end_time) * 700) / ($interval_length($end_time) * $based)]]% </th>"
    set total [expr $total + $colsum($end_time)]
}

doc_body_append "<th>$total</tr></table>"
doc_set_property title "[_ intranet-timesheet2.lt_Timeline_for_project_]"


