# /packages/intranet-timesheet2/www/absences/capacity-planning.tcl
#
# Copyright (C) 1998-2004 various parties
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
    Capacity planning 
    @author Klaus Hofeditz (klaus.hofeditz@project-open.com)

} {
    { order_by "Project nr" }
    { include_subprojects_p 0 }
    { project_status_id 0 }
    { project_type_id:integer 0 }
    { letter:trim "" }
    { cap_month "" }
    { cap_year "" }
    { start_idx:integer 0 }
    { how_many "" }
    { view_name "project_list" }
    { filter_advanced_p:integer 0 }
}


proc round_down {val rounder} {
       set nval [expr floor($val*$rounder) /$rounder]
       return $nval
       }

# General settings
set show_context_help_p 0
set user_id [ad_maybe_redirect_for_registration]
set page_title "Capacity Planning"
set context [list "Permissions"]
set subsite_id [ad_conn subsite_id]
set context_bar [im_context_bar $page_title]
set url_stub [im_url_with_query]
set project_url "/intranet/projects/view?project_id="
set user_url "/intranet/users/view?user_id="
set floating_point_helper ".0"


# Date settings
set days_in_past 7
set date_format [im_l10n_sql_date_format]
db_1row todays_date "
select
        to_char(sysdate::date - :days_in_past::integer, 'YYYY') as todays_year,
        to_char(sysdate::date - :days_in_past::integer, 'MM') as todays_month,
        to_char(sysdate::date - :days_in_past::integer, 'DD') as todays_day
from dual
"

if {"" == $cap_month} {
    set cap_month "[lindex [split [expr $todays_month$floating_point_helper + 1] "." ] 0 ]"
}

if {"" == $cap_year} {
    set cap_year "$todays_year"
}

if { ("" != $cap_month && ![regexp {^[0-9][0-9]$} $cap_month] && ![regexp {^[0-9]$} $cap_month]) || ("" != $cap_month && [lindex [split $cap_month$floating_point_helper "."] 0 ] > 12) } {
    ad_return_complaint 1 "Month doesn't have the right format.<br>
    Current value: '$cap_month'<br>
    Expected format: 'MM'"
}


# Please verify - might need adjustment
set im_absence_type_vacation 5000
set im_absence_type_personal 5001
set im_absence_type_sick 5002
set im_absence_type_travel 5003
set im_absence_type_bankholiday 5005 
set im_absence_type_training 5004

# set excluded projects
# set exclude_closed_projects [im_sub_categories [im_project_status_deleted] ]
# set exclude_deleted_projects [im_sub_categories [im_project_status_closed]]
# set exclude_status_id [concat $exclude_closed_projects $exclude_deleted_projects] 
set exclude_status_id 0


# Date operations 
set first_day_of_month ""
append first_day_of_month $cap_year "-" $cap_month "-01"

set number_days_month ""
set number_days_month [db_string get_number_days_month "SELECT date_part('day','$first_day_of_month'::date + '1 month'::interval - '1 day'::interval)" -default 0]

set last_day_of_month ""
set last_day_of_month [db_string get_number_days_month "select to_date( '$cap_year' || '-' || '$cap_month' || '-' || '$number_days_month','yyyy-mm-dd')+1 from dual;" -default 0]

# set sql for top line (user and absences)
# workdays: total business days - absences - saturday/sunday - bank holidays

set title_sql "
	select 
		p.person_id, 
		p.first_names, 
		p.last_name,
			(select count(*) from (select * from im_absences_working_days_month(p.person_id,$cap_month,$cap_year) t(days int))ct) as 
		work_days,
			(select
                        	count(*)
	                from
        	                im_user_absences a,
                	        (select im_day_enumerator as d from im_day_enumerator(to_date('$first_day_of_month','mm/dd/yyyy'), to_date('$last_day_of_month','yyyy-mm-dd'))) d
	                where
        	                a.start_date <=  to_date('$last_day_of_month','yyyy-mm-dd')::date and
                	        a.end_date >= to_date('$first_day_of_month','yyyy-mm-dd')::date and
                        	d.d between a.start_date and a.end_date and
				a.owner_id = p.person_id and
	                        a.absence_type_id = $im_absence_type_vacation) as 
		vacation_days,
                        (select
                                count(*)
                        from
                                im_user_absences a,
                                (select im_day_enumerator as d from im_day_enumerator(to_date('$first_day_of_month','mm/dd/yyyy'), to_date('$last_day_of_month','yyyy-mm-dd'))) d
                        where
                                a.start_date <=  to_date('$last_day_of_month','yyyy-mm-dd')::date and
                                a.end_date >= to_date('$first_day_of_month','yyyy-mm-dd')::date and
                                d.d between a.start_date and a.end_date and
                                a.owner_id = p.person_id and
                                a.absence_type_id = $im_absence_type_training) as
                training_days,
                        (select
                                count(*)
                        from
                                im_user_absences a,
                                (select im_day_enumerator as d from im_day_enumerator(to_date('$first_day_of_month','mm/dd/yyyy'), to_date('$last_day_of_month','yyyy-mm-dd'))) d
                        where
                                a.start_date <=  to_date('$last_day_of_month','yyyy-mm-dd')::date and
                                a.end_date >= to_date('$first_day_of_month','yyyy-mm-dd')::date and
                                d.d between a.start_date and a.end_date and
                                a.owner_id = p.person_id and
	                                (a.absence_type_id = $im_absence_type_personal or 
					 a.absence_type_id = $im_absence_type_sick or 
					 a.absence_type_id = $im_absence_type_travel)
				) as 
                other_absences,
			(select
				sum(c.days_capacity) 
			from 
				im_capacity_planning c,
				im_projects proj
			where 
				c.user_id= p.person_id and 
				c.project_id = proj.project_id and 
				proj.project_status_id not in ([join $exclude_status_id ","])
				) as 
		workload  
	from 
		persons p,
		acs_rels r, 
		membership_rels mr 
	where 	
		r.rel_id = mr.rel_id and 
		r.object_id_two = p.person_id and 
		r.object_id_one = 463 and 
		mr.member_state = 'approved'
"

# ---------------------------------------------------------------
# Create table header
# ---------------------------------------------------------------

set table_header_html ""
set table_header_html "<form action='/intranet-timesheet2/absences/capacity-planning-2.tcl' method='POST'>[export_form_vars cap_month cap_year]"
append table_header_html "<table border='0'><tbody><tr>\n"
append table_header_html "<td colspan='4'></td>"

# ---------------------------------------------------------------
# Create top column (employees) 
# ---------------------------------------------------------------

set ctr_employees 0 

append table_header_html "<td><table border=0 style='margin:3px' class='table_fixed_height'><tbody><tr><td>[lang::message::lookup "" intranet-core.User_Id "User Id"]:</b></td></tr>\n"
append table_header_html "<tr><td><b>[lang::message::lookup "" intranet-core.Username "Name"]:</b><br><br></td></tr>\n"
append table_header_html "<tr><td><b>[lang::message::lookup "" intranet-core.Workload "Workload"]:</b></td></tr>\n"
append table_header_html "<tr><td><b>[lang::message::lookup "" intranet-timesheet2.Workdays "Workdays"]:</b></td></tr>\n"  
append table_header_html "<tr><td><b>[lang::message::lookup "" intranet-core.Vacation "Vacation"]:</b></td></tr>\n"
append table_header_html "<tr><td><b>[lang::message::lookup "" intranet-timesheet2.Training "Training"]:</b></td></tr>\n"  
append table_header_html "<tr><td><b>[lang::message::lookup "" intranet-timesheet2.OtherAbsences "Other absences"]:</b></td></tr>\n"  
append table_header_html "</tbody></table></td>"



db_foreach projects_info_query $title_sql  {

    	if { ![empty_string_p $workload] } {
		set workload_formatted [expr [round_down [expr $workload / [concat $work_days$floating_point_helper]] 100 ] * 100]
	} else {
                set workload_formatted 0
	}
	if { $workload_formatted > 100} {
		set workload_formatted "<span style='color:red;font-weight:bold'>$workload_formatted%</span>"
	} else {
		append workload_formatted "%" 
	}
	append table_header_html "<td valign='top'><table border=0 style='margin:3px' class='table_fixed_height'><tbody>\n"
	append table_header_html "<tr><td><a href='$user_url$person_id'>$person_id</a></td></tr>\n"
	append table_header_html "<tr height='40px'><td><b>$first_names<br>$last_name</b></td></tr>\n"
	append table_header_html "<tr><td>$workload_formatted</td></tr>\n"
	append table_header_html "<tr><td>$work_days</td></tr>\n"
	append table_header_html "<tr><td>$vacation_days</td></tr>\n"
        append table_header_html "<tr><td>$training_days</td></tr>\n"
        append table_header_html "<tr><td>$other_absences</td></tr>\n"
	append table_header_html "<tbody></table></td>\n"
	set employee_array($ctr_employees) $person_id
	incr ctr_employees
}

append table_header_html "</tr>"

# ---------------------------------------------------------------
# Set capacity arr
# ---------------------------------------------------------------

set sql "
	select 
		c.days_capacity,
		c.project_id,
		c.user_id
 	from 
		im_capacity_planning c,
                users u,
                acs_rels r,
                membership_rels mr,
		im_projects p
	where 
                r.rel_id = mr.rel_id and
                r.object_id_two = u.user_id and
                r.object_id_one = 463 and
                mr.member_state = 'approved' and 
		c.year = :cap_year and  
		c.month = :cap_month and 
		c.user_id = u.user_id and 
		c.project_id = p.project_id and
		p.project_status_id not in ([join $exclude_status_id ","]) 	
"

db_foreach sql $sql {
	set cap_array_index [concat $user_id.$project_id]
	set cap_array($cap_array_index) $days_capacity
}

# ---------------------------------------------------------------
# Create table body
# ---------------------------------------------------------------



set table_body_html ""

# build sql 

# exclude sub-projects
set exclude_subprojects_p 1 

# do not exclude types 
set exclude_type_id ""

# do not exclude tasks
set exclude_tasks_p 1

set current_user_id [ad_get_user_id]
set max_project_name_len 50

set list_sort_order [parameter::get_from_package_key -package_key "intranet-timesheet2" -parameter TimesheetAddHoursSortOrder -default "name"]



    # ---------------------------------------------------------
    # Compile "criteria"

    set p_criteria [list]

    if {$exclude_subprojects_p} {
        lappend p_criteria "p.parent_id is null"
    }

    if {0 != $exclude_status_id && "" != $exclude_status_id} {
        lappend p_criteria "p.project_status_id not in ([join $exclude_status_id ","])"
    }

    if {0 != $exclude_type_id && "" != $exclude_type_id} {
        lappend p_criteria "p.project_type_id not in ([join [im_sub_categories $exclude_type_id] ","])"
        # No restriction of type on parent project!
    }

    if {$exclude_tasks_p} {
        lappend p_criteria "p.project_type_id not in ([join [im_sub_categories [im_project_type_task]] ","])"
    }

    if {0 != $project_type_id && "" != $project_type_id} {
        lappend p_criteria "p.project_type_id in ([join [im_sub_categories $project_type_id] ","])"
        # No restriction on parent's project type!
    }
	
	set days_current_month [db_string get_view_id "SELECT date_part('day', '$cap_year-$cap_month-01' ::date + '1 month'::interval - '1 day'::interval)" -default 0]
    	lappend p_criteria "p.end_date :: date >= '$cap_year/$cap_month/$days_current_month' :: date"  

    # -----------------------------------------------------------------
    # Compose the SQL

    set where_clause [join $p_criteria " and\n\t\t\t\t\t"]
    if { ![empty_string_p $where_clause] } {
        set where_clause " and $where_clause"
    }

    switch $list_sort_order {
        name { set sort_order "lower(p.project_name)" }
        order { set sort_order "p.sort_order" }
        legacy { set sort_order "p.tree_sortkey" }
        default { set sort_order "lower(p.project_nr)" }
    }
    set sql "
                select
                        p.project_id,
                        substring(p.project_name for :max_project_name_len) as project_name_shortened,
			to_char(start_date, 'DD/MM/YYYY') as start_date,
                        to_char(end_date, 'DD/MM/YYYY') as end_date,
			im_name_from_user_id(p.project_lead_id) as lead_name,
			(
				select 
					 sum(coalesce(tt.planned_units,0)) 
				from 
					im_timesheet_tasks tt
				where 
					task_id in 
					( 
					  select 
						children.project_id
					  from 
						im_projects parent, 
						im_projects children
					  where 
						children.tree_sortkey between parent.tree_sortkey and tree_right(parent.tree_sortkey)
						and parent.tree_sortkey in  
						(
							select tree_sortkey from im_projects where project_id=28960
						)
					)
			) as sum_planned_units, 
			( 
				select 
					sum(coalesce(h.days,0))				
				from
					im_hours h
				where 
					h.project_id in
					( 
					select 
						children.project_id
					from 
						im_projects parent, 
						im_projects children
					where 
						children.tree_sortkey between parent.tree_sortkey and tree_right(parent.tree_sortkey)
						and parent.tree_sortkey in  
						(
							select tree_sortkey from im_projects where project_id=28960
						)
					)
			) as sum_logged_units
		from
			im_projects p
                where
                        p.parent_id is null
			$where_clause

                order by
                        p.project_name
    "


    set bgcolor(0) " class=roweven "
    set bgcolor(1) " class=rowodd "
    set ctr 0

    append table_body_html "<tr>\n"
    append table_body_html "<td style='background-color:#ccc;font-weight:bold'>[lang::message::lookup "" intranet-core.Project_name "Project Name"]</td>\n"
    append table_body_html "<td style='background-color:\#ccc;font-weight:bold'>[lang::message::lookup "" intranet-core.Project_Manager "Project Manager"]</td>\n"
    append table_body_html "<td style='background-color:#ccc;font-weight:bold'>[lang::message::lookup "" intranet-core.Start_Date "Start Date"]</td>\n"
    append table_body_html "<td style='background-color:#ccc;font-weight:bold'>[lang::message::lookup "" intranet-core.End_Date "End Date"]</td>\n"
    append table_body_html "<td style='background-color:#ccc;font-weight:bold'>[lang::message::lookup "" intranet-core.AvailableDays "Days available"]</td>\n"
    append table_body_html "<td colspan='1000'>&nbsp;</td></tr>\n"

    db_foreach project_name $sql {
	append table_body_html "<tr$bgcolor([expr $ctr % 2])>\n"
	append table_body_html "<td><a href='$project_url$project_id'>$project_name_shortened</a></td>\n"
        append table_body_html "<td>$lead_name</td>\n"
	append table_body_html "<td>$start_date</td>\n"	
	append table_body_html "<td>$end_date</td>\n"	

	if { [empty_string_p $sum_planned_units] } { set sum_planned_units 0}
        if { [empty_string_p $sum_logged_units] } { set sum_logged_units 0}
	append table_body_html "<td align='center'>[expr $sum_planned_units - $sum_logged_units]</td>\n"

	for { set i 1 } { $i <= $ctr_employees } { incr i } {
		set cap_array_index [concat $employee_array([expr $i-1]).$project_id]		
		if { [info exists cap_array($cap_array_index)] } {
			set cap_textbox_value $cap_array($cap_array_index) 	
		} else {
			set cap_textbox_value "" 	
		}
		append table_body_html "<td><input type='textbox' name='capacity.$cap_array_index' value='$cap_textbox_value' size='3'/></td>\n"
	}	
        append table_body_html "</tr>\n"
	incr ctr
    }

# ---------------------------------------------------------------
# Create table footer
# ---------------------------------------------------------------

append table_footer_html "</tbody><tr><td>&nbsp;</td></tr><tr><td colspan='100' align='right'><input type=submit value='[lang::message::lookup "" intranet-core.BtnSaveUpdate "Save/Update"]'></td></tr></table>\n</form>"

# ---------------------
# final standard stuff
# ---------------------

set filter_html "
<form method=get name=capacity_filter action='/intranet-timesheet2/absences/capacity-planning'>
<table border=0 cellpadding=3 cellspacing=3>
"


# if {[im_permission $user_id "view_projects_all"]} {
#    append filter_html "
#  <tr>
#    <td class=form-label>[_ intranet-core.Project_Status]:</td>
#    <td class=form-widget>[im_category_select -include_empty_p 1 "Intranet Project Status" project_status_id $project_status_id]</td>
#  </tr>
#    "
# }


append filter_html "
  <tr>
<td class=form-label>[lang::message::lookup "" intranet-core.Month "Month"]</td
            <td class=form-widget>
              <input type=textfield name=cap_month value=$cap_month size='2' maxlength='2'>
            </td>
  </tr>
  <tr>
<td class=form-label>[lang::message::lookup "" intranet-core.Year "Year"]</td>
            <td class=form-widget>
              <input type=textfield name=cap_year value=$cap_year size='4' maxlength='4'>
            </td>
  </tr>
"
append filter_html "
  <tr>
    <td class=form-label></td>
    <td class=form-widget>
          <input type=submit value='[lang::message::lookup "" intranet-core.Action_Go "Go"]' name=submit>
    </td>
  </tr>
"

append filter_html "</table>\n</form>\n"

# Left Navbar is the filter/select part of the left bar
set left_navbar_html "
        <div class='filter-block'>
                <div class='filter-title'>
                   #intranet-core.Filter_Projects#
                </div>
                $filter_html
        </div>
      <hr/>
"

append left_navbar_html "
        <div class='filter-block'>
        <div class='filter-title'>
            #intranet-core.Admin_Projects#
        </div>
        </div>
"

