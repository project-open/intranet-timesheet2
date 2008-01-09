# /packages/intranet-timesheet2/www/hours/index.tcl
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
    Calendar format display of user's hours with links 
    to log more hours, if the user is looking at him/
    herself

    @param on_which_table table we're viewing hours against
    @param date day in ansi format in the month we're currently viewing
    @param julian_date day in julian format in the month we're currently viewing
    @param user_id the user for whom we're viewing hours. Defaults to currently logged in user.
    @param project_id The user group for which we're viewing hours. Defaults to all groups.
    @param return_url Return URL
 
    @author Michael Bryzek (mbryzek@arsdigita.com)
    @author Frank Bergmann (frank.bergmann@project-open.com)
} {
    { date "" }
    { julian_date "" }
    { user_id:integer "" }
    { project_id:integer "" }
    { return_url "" }
    { header "" }
    { message:allhtml "" }
}

# ---------------------------------------------------------------
# Security & Defaults
# ---------------------------------------------------------------

set current_user_id [ad_maybe_redirect_for_registration]
if {"" == $user_id} {
    set user_id $current_user_id
}
set user_name [db_string user_name_sql "select im_name_from_user_id(:user_id) from dual"]

if {"" == $return_url} {
    set return_url "[ad_conn url]?[ad_conn form]"
}

set write_p [im_is_user_site_wide_or_intranet_admin $current_user_id]
if {$user_id == $current_user_id} {
    # Can do anything to your own hours :)
    set write_p 1
}
set page_title "[_ intranet-timesheet2.Hours_by_user_name]"
set context_bar [im_context_bar "[_ intranet-timesheet2.Hours]"]

# Get the project name restriction in case project_id is set
set project_restriction ""
if {"" != $project_id} {
    set project_name [db_string project_name "select project_name from im_projects where project_id = :project_id"]
    append page_title " on $project_name"
    set project_restriction "and project_id = :project_id"
}

# Default the date to today if there is no date specified
if {"" ==  $date } {
    if {"" != $julian_date} {
	set date [db_string julian_date_select "select to_char( to_date(:julian_date,'J'), 'YYYY-MM-DD') from dual"]
    } else {
	set date [db_string ansi_date_select "select to_char( sysdate, 'YYYY-MM-DD') from dual"]
    }
} 
ns_log Notice "/intranet-timesheet2/index: date=$date"


# ---------------------------------------------------------------
# Render the Calendar widget
# ---------------------------------------------------------------

set calendar_details [ns_set create calendar_details]

# figure out the first and last julian days in the month
# This call defines a whole set of variables in our environment
calendar_get_info_from_db $date

# --------------------------------------------------------------
# Grab all the hours from im_hours
set sql "
	select 
		to_char(day, 'J') as julian_date, 
		sum(hours) as hours
	from
		im_hours
	where
		user_id = :user_id
		and day between to_date(:first_julian_date, 'J') and to_date(:last_julian_date, 'J') 
		$project_restriction
	group by 
		to_char(day, 'J')
"

db_foreach hours_logged $sql {
    set users_hours($julian_date) $hours
}


# --------------------------------------------------------------
# Get the unconfirmed hours for the week
if {[db_column_exists im_hours conf_object_id]} {
    set sql "
	select 
		to_char(day, 'J') as julian_date, 
		sum(hours) as hours
	from
		im_hours
	where
		user_id = :user_id
		and day between to_date(:first_julian_date, 'J') and to_date(:last_julian_date, 'J') 
		and conf_object_id is null
		$project_restriction
	group by 
		to_char(day, 'J')
    "
    db_foreach hours_logged $sql {
	set unconfirmed_hours($julian_date) $hours
    }
}



# --------------------------------------------------------------
# Render the calendar

set hours_for_this_week 0.0
set unconfirmed_hours_for_this_week 0.0
set absence_list [absence_list_for_user_and_time_period $user_id $first_julian_date $last_julian_date]
set absence_index 0
set curr_absence ""

# Day of week: 1=Sunday, 2=Mon, ..., 7=Sat.
set day_of_week 1

# And now fill in information for every day of the month
for { set current_date $first_julian_date} { $current_date <= $last_julian_date } { incr current_date } {

    # User's hours for the day
    set hours ""
    if { [info exists users_hours($current_date)] && ![empty_string_p $users_hours($current_date)] } {
 	set hours "$users_hours($current_date) hours"
	set hours_for_this_week [expr $hours_for_this_week + $users_hours($current_date)]
    } else {
	set hours "<font color=#666666><em>[_ intranet-timesheet2.log_hours]</em></font>"
    }


    # Sum up unconfirmed_hours
    if {![info exists unconfirmed_hours($current_date)]} { set unconfirmed_hours($current_date) "" }
    if {"" == $unconfirmed_hours($current_date)} { set unconfirmed_hours($current_date) 0 }
    set unconfirmed_hours_for_this_week [expr $unconfirmed_hours_for_this_week + $unconfirmed_hours($current_date)]

    # Render the "Sunday" link to log "hours for the week"
    if {$day_of_week == 1 } {
	append hours "<br>
		<a href=[export_vars -base "new" {user_id {julian_date $current_date} {show_week_p 1} return_url}]
		><font color=#666666><em>log hours for the week</em></font></a>
	"
    }

    # User's Absences for the day
    set curr_absence [lindex $absence_list $absence_index]
    if {"" != $curr_absence} { set curr_absence "<br>$curr_absence" }

    if {$write_p} {
        set hours_url [export_vars -base "new" {user_id {julian_date $current_date} {show_week_p 0} return_url}]
	set html "<a href=$hours_url>$hours</a>$curr_absence"
    } else {
	set html "$curr_absence"
    }

    # Render the "Saturday" sum of the weekly hours
    if {$day_of_week == 7 } {
	append html "<br>
		<a href=[export_vars -base "week" {{julian_date $current_date} user_id}]
		>[_ intranet-timesheet2.Week_total_1] $hours_for_this_week</a>
	"

	if {0 != $unconfirmed_hours_for_this_week} {
	    set start_date_julian [expr $current_date - 6]
	    set end_date_julian $current_date

	    set unconf_url [export_vars -base "/intranet-timesheet2-workflow/conf-objects/new-timesheet-workflow" { user_id start_date_julian end_date_julian return_url}]
	    set button_txt [lang::message::lookup "" intranet-timesheet2.Confirm_weekly_hours "Confirm %unconfirmed_hours_for_this_week% Hours"]
	    append html "<p>&nbsp;</p><a href='$unconf_url' class=button>$button_txt</a>"
	}
    }

    ns_set put $calendar_details $current_date "$html<br>&nbsp;"
    
    # we keep track of the day of the week we are on
    incr day_of_week
    if { $day_of_week > 7 } {
	set day_of_week 1
	set hours_for_this_week 0.0
	set unconfirmed_hours_for_this_week 0.0
    }
    set curr_absence ""
    incr absence_index
}

set prev_month_template "
<font color=white>&lt;</font> 
<a href=\"index?[export_url_vars user_id]&date=\$ansi_date\">
  <font color=white>\[_ intranet-timesheet2.$prev_month_name] </font>
</a>"
set next_month_template "
<a href=\"index?[export_url_vars user_id]&date=\$ansi_date\">
  <font color=white>\[_ intranet-timesheet2.$next_month_name]</font>
</a> 
<font color=white>&gt;</font>"

set day_bgcolor "#efefef"
set day_number_template "<!--\$julian_date--><font size=-1>\$day_number</font>"

ns_log Notice "/intranet-timesheet2/index: calendar_details=$calendar_details"

set page_body [calendar_basic_month \
	-calendar_details $calendar_details \
	-days_of_week "[_ intranet-timesheet2.Sunday] [_ intranet-timesheet2.Monday] [_ intranet-timesheet2.Tuesday] [_ intranet-timesheet2.Wednesday] [_ intranet-timesheet2.Thursday] [_ intranet-timesheet2.Friday] [_ intranet-timesheet2.Saturday]" \
	-next_month_template $next_month_template \
	-prev_month_template $prev_month_template \
	-day_number_template $day_number_template \
	-day_bgcolor $day_bgcolor \
	-date $date \
	-prev_next_links_in_title 1 \
	-fill_all_days 1 \
	-empty_bgcolor "#cccccc"]
