# /packages/intranet-timesheet2/tcl/intranet-timesheet-procs.tcl
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

ad_library {
    Definitions for the intranet timesheet

    @author unknown@arsdigita.com
    @author frank.bergmann@project-open.com
}

# ---------------------------------------------------------------------
# Analyze logged hours
# ---------------------------------------------------------------------

ad_proc -public im_timesheet_home_component {user_id} {
    Creates a HTML table showing a box with basic statistics about
    the current project and a link to log the users hours.
} {

    set add_hours [im_permission $user_id "add_hours"]

    # skip the entire component if the user doesn't have
    # the permission to log hours
    if {!$add_hours} { return "" }

    set add_absences [im_permission $user_id "add_absences"]
    set view_hours_all [im_permission $user_id view_hours_all]
    if {!$add_hours && !$add_absences && !$view_hours_all} { return "" }

    set hours_html ""

    if { [catch {
        set num_hours [hours_sum_for_user $user_id "" 7]
    } err_msg] } {
        set num_hours 0
    }

    if { $num_hours == 0 && $add_hours } {
	set log_them_now_link "<a href=/intranet-timesheet2/hours/index>"
        append hours_html "<b>[_ intranet-timesheet2.lt_You_havent_logged_you]</a></b>\n"
    } else {
        append hours_html "[_ intranet-timesheet2.lt_You_logged_num_hours_]"
    }

    if {[im_permission $user_id view_hours_all]} {
        append hours_html "
	    <ul>
	    <li><a href=/intranet-timesheet2/hours/projects?[export_url_vars user_id]>
		[_ intranet-timesheet2.lt_View_your_hours_on_al]</a>
	    <li><a href=/intranet-timesheet2/hours/total?[export_url_vars]>
		[_ intranet-timesheet2.lt_View_time_spent_on_al]</a>
	    <li><a href=/intranet-timesheet2/hours/projects?[export_url_vars]>
		[_ intranet-timesheet2.lt_View_the_hours_logged]</a>
	    <li><a href=\"/intranet-timesheet2/weekly_report\">
		[_ intranet-timesheet2.lt_View_hours_logged_dur]</a>
        "
    }

    set dw_light_exists_p [db_string dw_light_exists_p {
        select count(*) from apm_packages
        where package_key = 'intranet-dw-light'
    } -default 0]

    if {[im_permission $user_id view_hours_all] && $dw_light_exists_p} {
        append hours_html "
	    <li><a href=/intranet-dw-light/timesheet.csv>
	    [lang::message::lookup "" intranet-dw-light.Export_Timesheet_Cube "Export Timesheet Cube"]
            </a>\n"
    }


    if {$add_hours} {
	set log_hours_link "<a href=/intranet-timesheet2/hours/index>"
	set add_html "<li>[_ intranet-timesheet2.lt_Log_your_log_hours_li]</a>\n"
    }

    # Show the "Work Absences" link only to in-house staff.
    # Clients and Freelancers don't necessarily need it.
    if {$add_absences} {
        append add_html "/ <a href=/intranet-timesheet2/absences/new>[_ intranet-timesheet2.absences]</a>\n"
    }
    append hours_html "$add_html</ul>"
    return $hours_html
}

ad_proc -public im_timesheet_project_component {user_id project_id} {
    Creates a HTML table showing a box with basic statistics about
    the current project and a link to log the users hours.
} {
    im_project_permissions $user_id $project_id view read write admin

    if { ![info exists return_url] } {
	set return_url "[ad_conn url]?[ad_conn query]"
    }

    set hours_logged "<ul>"
    set info_html ""

    if {$admin} {
        set total_hours [hours_sum $project_id]
	set total_hours_str "[util_commify_number $total_hours]"
        set info_html "[_ intranet-timesheet2.lt_A_total_of_total_hour]"
        if { $total_hours > 0 } {
           append hours_logged "
          <li>
            <a href=/intranet-timesheet2/hours/one-project?project_id=$project_id>
              [_ intranet-timesheet2.lt_See_the_breakdown_by_]
            </a>\n"
        }

	append hours_logged "<li><a href=\"/intranet-timesheet2/weekly_report?project_id=$project_id\">[_ intranet-timesheet2.lt_View_hours_logged_by_]</a>"


    }


    if {$read} {
	set total_hours_str "[hours_sum_for_user $user_id $project_id]"
        append info_html "<br>[_ intranet-timesheet2.lt_You_have_loged_total_].\n"
        set hours_today [hours_sum_for_user $user_id "" 1]
        if { $hours_today == 0 } {
	    set log_hours_link "<a href=/intranet-timesheet2/hours/new?project_id=$project_id&[export_url_vars return_url]>"
            append hours_logged "<li><font color=\"\#FF0000\">[_ intranet-timesheet2.lt_Today_you_didnt_log_y]</font> [_ intranet-timesheet2.lt_Log_your_log_hours_li]</a>\n"
        } else {
	    set log_hours_link "<a href=\"/intranet-timesheet2/hours/new?[export_url_vars project_id return_url]\">"
            append hours_logged "<li>[_ intranet-timesheet2.lt_Log_your_log_hours_li_1]</a>\n"
        }
	# Show the "Work Absences" link only to in-house staff.
        # Clients and Freelancers don't necessarily need it.
	if {[im_permission $user_id "add_absences"]} {
	    append hours_logged " / <a href=/intranet-timesheet2/absences/new>[_ intranet-timesheet2.absences]</a>\n"
	}

    }

    if {![string equal "" $hours_logged]} {
        append hours_logged "</ul>\n"
    }
    append info_html "$hours_logged</ul>"

    return $info_html
}


ad_proc absence_list_for_user_and_time_period {user_id first_julian_date last_julian_date} {
    For a given user and time period, this proc  returns a list 
    of elements where each element corresponds to one day and describes its
    "work/vacation type".
} {
    # Select all vacation periods that have at least one day
    # in the given time period.
    set sql "
select
	to_char(start_date,'J') as start_date,
	to_char(end_date,'J') as end_date,
	im_category_from_id(absence_type_id) as absence_type,
        absence_id
from 
	im_user_absences
where 
	owner_id = :user_id
	and start_date <= to_date(:last_julian_date,'J')
	and end_date   >= to_date(:first_julian_date,'J')"

    # Initialize array with "" elements.
    for {set i $first_julian_date} {$i<=$last_julian_date} {incr i} {
	set vacation($i) ""
    }

    # Process vacation periods and modify array accordingly.
    db_foreach vacation_period $sql {
	for {set i [max $start_date $first_julian_date]} {$i<=[min $end_date $last_julian_date]} {incr i } {
	   set vacation($i) "<a href=\"/intranet-timesheet2/absences/view?absence_id=$absence_id\">[_ intranet-timesheet2.Absent_1]</a> $absence_type<br>"
	}
    }
    # Return the relevant part of the array as a list.
    set result [list]
    for {set i $first_julian_date} {$i<=$last_julian_date} {incr i} {
	lappend result $vacation($i)
    }
    return $result
}


ad_proc hours_sum_for_user { user_id { project_id "" } { number_days "" } } {
    Returns the total number of hours the specified user logged for
    whatever else is included in the arg list 
} {

    set criteria [list "user_id=:user_id"]
    if { ![empty_string_p $project_id] } {
	lappend criteria "project_id = :project_id"
    }
    if { ![empty_string_p $number_days] } {
	lappend criteria "day >= to_date(to_char(sysdate,'yyyymmdd'),'yyyymmdd') - $number_days"	
    }
    set where_clause [join $criteria "\n    and "]
    set num [db_string hours_sum \
	   "select sum(hours) from im_hours, dual  where $where_clause"]
    
    if {"" == $num} { set num 0}
    return $num
}

ad_proc hours_sum { project_id {number_days ""} } {
    Returns the total hours registered for the specified table and
    id. 
} {

    if { [empty_string_p $number_days] } {
	set days_back_sql ""
    } else {
	set days_back_sql " and day >= sysdate-:number_days"
    }

    set num [db_string hours_sum_for_group "
select 
	sum(hours)
from
	im_hours
where
	project_id = :project_id
	$days_back_sql
"]

    if {"" == $num} { set num 0 }
    return $num
}



ad_proc im_force_user_to_log_hours { conn args why } {
    If a user is not on vacation and has not logged hours since
    yesterday midnight, we ask them to log hours before using the
    intranet. Sets state in session so user is only asked once 
    per session.
} {
    set user_id [ad_maybe_redirect_for_registration]

    if { ![im_enabled_p] || ![ad_parameter TrackHours "" 0] } {
	# intranet or hours-logging not turned on. Do nothing
	return filter_ok
    } 
    
    if { ![im_permission $user_id add_hours] } {
	# The user doesn't have "permissions" to log his hours
	return filter_ok
    } 
    
    set last_prompted_time [ad_get_client_property intranet user_asked_to_log_hours_p]

    if { ![empty_string_p $last_prompted_time] && \
	   $last_prompted_time > [expr [ns_time] - 60*60*24] } {
	# We have already asked the user in this session, within the last 24 hours, 
	# to log their hours
	return filter_ok
    }
    # Let's see if the user has logged hours since 
    # yesterday midnight. 
    # 

    if { $user_id == 0 } {
	# This can't happen on standard acs installs since intranet is protected
	# But we check any way to prevent bugs on other installations
	return filter_ok
    }

    db_1row hours_logged_by_user \
	   "select decode(count(*),0,0,1) as logged_hours_p, 
		   to_char(sysdate - 1,'J') as julian_date
		from im_hours h, users u, dual
		where h.user_id = :user_id
		and h.user_id = u.user_id
		and h.hours > 0
		and h.day <= sysdate
		and (u.on_vacation_until >= sysdate
    		    or h.day >= to_date(u.second_to_last_visit,'yyyy-mm-dd')-1)"

    # Let's make a note that the user has been prompted 
    # to update hours or is okay. This saves us the database 
    # hit next time. 
    ad_set_client_property -persistent f intranet user_asked_to_log_hours_p [ns_time]

    if { $logged_hours_p } {
	# The user has either logged their hours or
	# is on vacation right now
	return filter_ok
    }

    # Pull up the screen to log hours for yesterday
    set return_url [im_url_with_query]
    ad_returnredirect "/intranet-timesheet2/hours/new?[export_url_vars return_url julian_date]"
    return filter_return
}



ad_proc im_hours_for_user { user_id { html_p t } { number_days 7 } } {
    Returns a string in html or text format describing the number of
    hours the specified user logged and what s/he noted as work done in
    those hours.  
} {
    set sql "
select 
	g.project_id, 
	g.project_name, 
	nvl(h.note,'no notes') as note, 
	to_char( day, 'Dy, MM/DD/YYYY' ) as nice_day, 
	h.hours
from 
	im_hours h, 
	user_groups g
where
	g.project_id = h.project_id
	and h.day >= sysdate - :number_days
	and user_id=:user_id
order by 
	lower(g.project_name), 
	day
"
    
    set last_id -1
    set pcount 0
    set num_hours 0
    set html_string ""
    set text_string ""

    db_foreach hours_for_user $sql {
	if { $last_id != $project_id } {
	   set last_id $project_id
	   if { $pcount > 0 } {
		append html_string "</ul>\n"
		append text_string "\n"
	   }
	   append html_string " <li><b>$project_name</b>\n<ul>\n"
	   append text_string "$project_name\n"
	   set pcount 1
	}
	append html_string "   <li>$nice_day ($hours hours): &nbsp; <i>$note</i>\n"
	append text_string "  * $nice_day ($hours hours): $note\n"
	set num_hours [expr $num_hours + $hours]
    }

    # Let's get the punctuation right on days
    set number_days_string "$number_days [_ intranet-timesheet2.days]"

    if { $num_hours == 0 } {
	set text_string "[_ intranet-timesheet2.lt_No_hours_logged_in_th]."
	set html_string "<b>$text_string</b>"
    } else {
	if { $pcount > 0 } {
	   append html_string "</ul>\n"
	   append text_string "\n"
	}
	set html_string "<b>[_ intranet-timesheet2.lt_num_hours_hours_logge]</b>
<ul>$html_string</ul>"
	set text_string "[_ intranet-timesheet2.lt_num_hours_hours_logge]
$text_string"
    }

    set ret $text_string
    if {[string equal $html_p t]} { set ret $html_string }
    return $ret
}

ad_proc -public im_hours_verify_user_id { { user_id "" } } {
    Returns either the specified user_id or the currently logged in
    user's user_id. If user_id is null, throws an error unless the
    currently logged in user is a site-wide or intranet administrator.
} {

    # Let's make sure the 
    set caller_id [ad_verify_and_get_user_id]
    if { [empty_string_p $user_id] || $caller_id == $user_id } {
	return $caller_id
    } 
    # Only administrators can edit someone else's hours
    if { [im_is_user_site_wide_or_intranet_admin $caller_id] } {
	return $user_id
    }

    # return an error since the logged in user is not editing his/her own hours
    set own_hours_link "<a href=time-entry?[export_ns_set_vars url [list user_id]]>[_ intranet-timesheet2.own_hours]</a>"
    ad_return_error "[_ intranet-timesheet2.lt_You_cant_edit_someone]" "[_ intranet-timesheet2.lt_It_looks_like_youre_t]"
    return -code return
}

ad_proc -public im_get_next_absence_link { { user_id } } {
    Returns a html link with the next absence of the given user_id
} {
    set sql "
select
     absence_id,
     to_char(start_date,'yyyy-mm-dd') as start_date,
     to_char(end_date, 'yyyy-mm-dd') as end_date
from
     im_user_absences, dual
where
     owner_id = :user_id and
     start_date >= to_date(sysdate,'yyyy-mm-dd')
order by
     start_date, end_date"

    set ret_val ""
    db_foreach select_next_absence $sql {
	set ret_val "<a href=\"/intranet-timesheet2/absences/view?absence_id=$absence_id\">$start_date - $end_date</a>"
	break
    }
    return $ret_val
}

