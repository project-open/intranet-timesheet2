# /packages/intranet-timesheet2/www/absences/capacity-planning-2.tcl
#
#
# Copyright (C) 2003 - 2010 ]project-open[
#
# All rights reserved. Please check
# http://www.project-open.com/ for licensing details.



ad_page_contract {
    Capacity planning 
    @author Klaus Hofeditz (klaus.hofeditz@project-open.com)

} {
    submit:optional
    capacity:array,float,optional
    { cap_month:integer "" }
    { cap_year:integer "" }
    {user_id_from_search:multiple}
}


set floating_point_helper ".0"

# Check Start & End-Date for correct format
if { ("" != $cap_month && ![regexp {^[0-9][0-9]$} $cap_month] && ![regexp {^[0-9]$} $cap_month]) || ("" != $cap_month && [lindex [split [expr $cap_month$floating_point_helper] "." ] 0 ] > 12) } {
    ad_return_complaint 1 "Month doesn't have the right format.<br>
    Current value: '$cap_month'<br>
    Expected format: 'MM'"
}

if {"" != $cap_year && ![regexp {^[0-9][0-9][0-9][0-9]$} $cap_year]} {
    ad_return_complaint 1 "Year doesn't have the right format.<br>
    Current value: '$cap_year'<br>
    Expected format: 'YYYY'"
}


foreach {cap_index cap_value} [array get capacity] {

	if {"" != $cap_value} {
		if {$cap_value < 0} {
			ad_return_complaint 1 "<li>[lang::message::lookup "" intranet-timesheet2.CapacityValuePositiveInteger "Value '%$cap_value%' not accepted, needs to be a positive, numeric value."]"
	                ad_script_abort
		}
		set list_key_comb [split $cap_index "."]
		set cap_user_id [lindex $list_key_comb 0]
		set cap_project_id [lindex $list_key_comb 1]

		if {[catch {
		    set capacity_p [db_string get_capacity "
			select 
				count(*)
			from 
				im_capacity_planning
			where 
				month = :cap_month and 
				year = :cap_year and 
				project_id = $cap_project_id and 
				user_id = $cap_user_id	
			" -default 0]

			if { 0 == $capacity_p} {
        		        db_dml write_capacity "
                		        insert into im_capacity_planning (user_id, project_id, month, year, days_capacity, last_modified)
					values ($cap_user_id, $cap_project_id, :cap_month, :cap_year, $cap_value, now())
	        	        "
			} else {
        		        db_dml write_capacity "
                		        update im_capacity_planning 
					set 
						days_capacity=$cap_value,
						last_modified = now()
                		        where 
						user_id = $cap_user_id and 
						project_id = $cap_project_id and 
						month=:cap_month and year=:cap_year
        		        "
			}

    		} errmsg]} {
			ad_return_complaint 1 "<li>[lang::message::lookup "" intranet-timesheet2-tasks.Unable_Update_Capacity "Unable to update capacity:<br><pre>$errmsg</pre>"]"
		 	ad_script_abort
    		}
	}
}

set user_id_from_search [join $user_id_from_search " "]

ad_returnredirect [export_vars -base "/intranet-timesheet2/absences/capacity-planning.tcl" {
        { cap_year "$cap_year" }
        { cap_month "$cap_month" }
        { user_id_from_search "$user_id_from_search" }
}]


