# /packages/intranet-timesheet2/www/hours/new.tcl
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
    Displays form to let user enter hours

    @param project_id
    @param julian_date 
    @param return_url 

    @author mbryzek@arsdigita.com
    @creation-date Jan 2000

    @cvs-id new.tcl,v 3.9.2.8 2000/09/22 01:38:37 kevin Exp
} {
    { project_id:integer 0 }
    { project_id_list:multiple "" }
    { julian_date "" }
    { return_url "" }
}

set user_id [ad_maybe_redirect_for_registration]
set bgcolor(0) " class=roweven "
set bgcolor(1) " class=rowodd "
if { [empty_string_p $julian_date] } {
    set julian_date [db_string sysdate_as_julian "select to_char(sysdate,'J') from dual"]
}

# "Log hours for a different day"
set different_date_url "index?[export_ns_set_vars url [list julian_date]]"

# "Log hours for a different project"
set different_project_url "other-projects?[export_url_vars julian_date]"


db_1row user_name_and_date "
select 
	im_name_from_user_id(user_id) as user_name,
	to_char(to_date(:julian_date, 'J'), 'fmDay fmMonth fmDD, YYYY') as pretty_date
from
	users
where
	user_id = :user_id" 


if {0 != $project_id} {

    # Project specified => only one project
    set one_project_only_p 1
    set statement_name "hours_for_one_group"

    set sql "
select
	p.project_name, 
	p.project_id
from 
	im_projects p
where 
	p.project_id = :project_id
order by 
	upper(project_name)"

} elseif {"" != $project_id_list} {

    set one_project_only_p 0
    set statement_name "hours_for_one_group"

    set sql "
select
	p.project_name, 
	p.project_id
from 
	im_projects p 
where 
	p.project_id in ([join $project_id_list ","])
order by 
	upper(project_name)"

} else {

    # Project_id unknown => slelect all projects
    set one_project_only_p 0
    set statement_name "hours_for_groups"

    set sql "   
select
	p.project_name,
	p.project_id
from 
	im_projects p,
	(   select 
		r.object_id_one as project_id 
	    from 
		im_projects p,
		acs_rels r,
		im_categories psc
	    where
		r.object_id_one = p.project_id
		and object_id_two = :user_id
		and p.project_status_id = psc.category_id
		and upper(psc.category) not in (
		    'CLOSED','INVOICED','PARTIALLY PAID',
                    'DECLINED','DELIVERED','PAID','DELETED','CANCELED'
                )

	UNION
	    select
		project_id
	    from
		im_hours h
	    where
		h.user_id = :user_id
		and h.day = to_date(:julian_date, 'J')
	) r
where 
	r.project_id =  p.project_id
order by 
	upper(p.project_name)"

}

set extra_sql "
	and p.group_id in (
		select map.group_id 
		from user_group_map map
		where map.user_id = :user_id
		UNION
		select h.project_id
		from im_hours h
		where h.user_id = :user_id
		and (h.hours is not null OR h.note is not null)
		and h.day = to_date(:julian_date, 'J')
	)
"



set page_title "[_ intranet-timesheet2.lt_Hours_for_pretty_date]"
set context_bar [im_context_bar [list index "[_ intranet-timesheet2.Hours]"] "[_ intranet-timesheet2.Add_hours]"]

set results ""
set ctr 0
db_foreach $statement_name $sql {
    set hours_sql "select h.hours, 
	h.note, 
	h.billing_rate
   from 
	im_hours h
     where 
	h.project_id = :project_id
	and h.day = to_date(:julian_date, 'J')
	and h.user_id = :user_id"
    if {![db_0or1row "get hours info" $hours_sql]} {
	set hours ""
	set note ""
	set billing_rate ""
    }
    append results "
 <tr $bgcolor([expr $ctr % 2])>
  <td valign=top>
    <A href=/intranet/projects/view?project_id=$project_id>
      $project_name
    </A>
  </td>
  <td valign=top>
    <INPUT NAME=hours.${project_id}.hours size=5 MAXLENGTH=5 value=\"$hours\"]>
  </td>
  <td valign=top>
    <TEXTAREA NAME=hours.${project_id}.note WRAP=SOFT COLS=30 ROWS=2>[ns_quotehtml [value_if_exists note]]</TEXTAREA>
  </td>
<!--
  <td valign=top>\$<INPUT NAME=hours.${project_id}.billing_rate size=6 MAXLENGTH=6 billing_rate=\"$billing_rate\"]>
  </td> 
-->
 </tr>\n"
    incr ctr
}


if { [empty_string_p $results] } {
    append results "
<tr><td align=center><b>
[_ intranet-timesheet2.lt_There_are_currently_n_1]<br>
[_ intranet-timesheet2.lt_Please_notify_your_ma]
</b></td></tr>\n"
}


set export_form_vars [export_form_vars julian_date return_url]
