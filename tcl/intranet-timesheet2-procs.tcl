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
# Constants
# ---------------------------------------------------------------------

ad_proc -public im_absence_type_vacation {} { return 5000 }
ad_proc -public im_absence_type_personal {} { return 5001 }
ad_proc -public im_absence_type_sick {} { return 5002 }
ad_proc -public im_absence_type_travel {} { return 5003 }
ad_proc -public im_absence_type_bank_holiday {} { return 5004 }


ad_proc -public im_absence_status_active {} { return 16000 }
ad_proc -public im_absence_status_deleted {} { return 16002 }
ad_proc -public im_absence_status_requested {} { return 16004 }
ad_proc -public im_absence_status_rejected {} { return 16006 }



# ---------------------------------------------------------------------
# Absences Permissions
# ---------------------------------------------------------------------

ad_proc -public im_absence_permissions {user_id absence_id view_var read_var write_var admin_var} {
    Fill the "by-reference" variables read, write and admin
    with the permissions of $user_id on $absence_id
} {
    upvar $view_var view
    upvar $read_var read
    upvar $write_var write
    upvar $admin_var admin
    
    set view 1
    set read 1
    set write 1
    set admin 1
    
    # No read - no write...
    if {!$read} {
        set write 0
        set admin 0
    }
}


# ---------------------------------------------------------------------
#
# ---------------------------------------------------------------------

ad_proc -public im_package_timesheet2_id {} {
    Returns the package id of the intranet-timesheet2 package
} {
    return [util_memoize "im_package_timesheet2_id_helper"]
}

ad_proc -private im_package_timesheet2_id_helper {} {
    return [db_string im_package_core_id {
        select package_id from apm_packages
        where package_key = 'intranet-timesheet2'
    } -default 0]
}



# ---------------------------------------------------------------------
# Create Cost Items for timesheet hours
# ---------------------------------------------------------------------

ad_proc -public im_timesheet2_sync_timesheet_costs {
    {-user_id 0}
    {-project_id 0}
    {-julian_date ""}
} {
    Check for im_hour items without associated timesheet
    cost items and generate the required items.
    This routine is called in two different ways:
    <li>As part of timesheet2/new-2 to generate items
        after a user has logged his/her hours and
    <li>Periodically as a schedule routine in order to
        create costs for new im_hours entries coming
        from an external application
} {
    set sync_timesheet_costs [parameter::get_from_package_key -package_key intranet-timesheet2 -parameter SyncHoursP -default 1]
    if {!$sync_timesheet_costs} { return }
    
    set default_currency [ad_parameter -package_id [im_package_cost_id] "DefaultCurrency" "" "EUR"]

    set user_sql ""
    set project_sql ""
    set julian_date_sql ""
    if {0 != $user_id} { set user_sql "and h.user_id = :user_id" }
    if {0 != $project_id} { set project_sql "and h.project_id = :project_id" }

    set sql "
	select
		h.*,
		h.day::date as hour_date,
		h.user_id as hour_user_id,
		coalesce(e.hourly_cost, 0) as billing_rate,
		coalesce(e.currency, :default_currency) as billing_currency,
		p.company_id as customer_id,
		p.project_nr,
		im_name_from_user_id(h.user_id) as user_name
	from
		im_hours h
		LEFT OUTER JOIN im_employees e ON (h.user_id = e.employee_id)
		LEFT OUTER JOIN im_projects p ON (h.project_id = p.project_id)
	where
		h.cost_id is null
		$user_sql
		$project_sql
	LIMIT 100
    "

    set cost_ids [list]
    db_foreach hours $sql {

	ns_log Notice "sync: uid=$hour_user_id, pid=$project_id, day=$day"
	set cost_name "Timesheet $hour_date $project_nr $user_name"
	set cost_id [im_cost::new -cost_name $cost_name -user_id $hour_user_id -creation_ip "0.0.0.0" -cost_type_id [im_cost_type_timesheet]]
	lappend cost_ids $cost_id
	db_dml update_hours "
		update	im_hours
		set	billing_rate = :billing_rate,
			cost_id = :cost_id
		where
			user_id = :hour_user_id
			and project_id = :project_id
			and day = :day
	"

	set cost_center_id [util_memoize "im_costs_default_cost_center_for_user $hour_user_id" 5]

        db_dml cost_update "
	        update  im_costs set
	                cost_name               = :cost_name,
	                project_id              = :project_id,
	                cost_center_id		= :cost_center_id,
	                customer_id             = :customer_id,
			provider_id		= :hour_user_id,
	                effective_date          = :day::timestamptz,
	                amount                  = :billing_rate * cast(:hours as numeric),
	                currency                = :billing_currency,
			payment_days		= 0,
	                vat                     = 0,
	                tax                     = 0,
	                description             = :note
	        where
	                cost_id = :cost_id
        "
    }
    return $cost_ids
}



ad_proc -public im_timesheet_costs_delete {
    -project_id
    -user_id
    -day_julian
} {
    Delete any cost items related to hours logged for the specified project
    and day.
} {
    set del_cost_ids [db_list del_cost_ids "
		select	h.cost_id
		from	im_hours h
		where	h.project_id = :project_id
			and h.user_id = :user_id
			and h.day = to_date(:day_julian, 'J')
    "]

    set ctr 0
    foreach cost_id $del_cost_ids {
	db_dml update_hours "
		    	update im_hours
			set cost_id = null
			where cost_id = :cost_id
	"
	db_string del_ts_costs "select im_cost__delete(:cost_id)"
	incr ctr
    }
    return $ctr
}





# ---------------------------------------------------------------------
# Analyze logged hours
# ---------------------------------------------------------------------

ad_proc -public im_timesheet_home_component {user_id} {
    Creates a HTML table showing a box with basic statistics about
    the current project and a link to log the users hours.
} {
    # skip the entire component if the user doesn't have
    # the permission to log hours
    set add_hours [im_permission $user_id "add_hours"]
    if {!$add_hours} { return "" }

    set add_absences [im_permission $user_id "add_absences"]
    set view_hours_all [im_permission $user_id view_hours_all]
    if {!$add_hours && !$add_absences && !$view_hours_all} { return "" }

    # Get the number of hours in the number of days, and whether
    # we should redirect if the user didn't log them...
    #
    set redirect_p [parameter::get -package_id [im_package_timesheet2_id] -parameter "TimesheetRedirectHomeIfEmptyHoursP" -default 0]
    set num_days [parameter::get -package_id [im_package_timesheet2_id] -parameter "TimesheetRedirectNumDays" -default 7]
    set expected_hours [parameter::get -package_id [im_package_timesheet2_id] -parameter "TimesheetRedirectNumHoursInDays" -default 32]
    set available_perc [util_memoize "db_string percent_available \"select availability from im_employees where employee_id = $user_id\" -default 100" 60]
    if {"" == $available_perc} { set available_perc 100 }
    set expected_hours [expr $expected_hours * $available_perc / 100]

    set hours_html ""
    set log_them_now_link "<a href=/intranet-timesheet2/hours/index>"
    set num_hours [im_timesheet_hours_sum -user_id $user_id -number_days $num_days]
    set absences_hours [im_timesheet_absences_sum -user_id $user_id -number_days $num_days]

    if {$num_hours == 0} {
        set message "<b>[_ intranet-timesheet2.lt_You_havent_logged_you]</a></b>\n"
    } else {
        set message "[_ intranet-timesheet2.lt_You_logged_num_hours_]"
    }

    set absences_hours_message ""
    if { [expr $num_hours + $absences_hours] < $expected_hours && $add_hours } {

	if {$absences_hours > 0} { 
	    set absences_hours_message [lang::message::lookup "" \
					intranet-timesheet2.and_absences_hours \
					"and %absences_hours% hours of absences"]
	}
	set default_message "
		You have only logged %num_hours% hours %absences_hours_message% 
		in the last %num_days% days out of %expected_hours% expected hours.
	"
	set message "<b>[lang::message::lookup "" intranet-timesheet2.You_need_to_log_hours $default_message]</b>"

	if {$redirect_p} {
	    set header [lang::message::lookup "" intranet-timesheet2.Please_Log_Your_Hours "Please Log Your Hours"]
	    ad_returnredirect [export_vars -base "/intranet-timesheet2/hours/index" {header message}]
	}
    }

    append hours_html $message

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
    append hours_html "$add_html"
    append hours_html "</ul>"


    # Add the <ul>-List of associated menus
    set bind_vars [list user_id $user_id]
    set menu_html [im_menu_ul_list "reporting-timesheet" $bind_vars]
    if {"" != $menu_html} {
	append hours_html "
		[lang::message::lookup "" intranet-timesheet2.Associated_reports "Associated Reports"]
		$menu_html
	"
    }

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

    set view_ours_all_p [im_permission $user_id "view_hours_all"]

    # disable the component for users who can neither see stuff nor add stuff
    set add_hours [im_permission $user_id "add_hours"]
    set view_hours_all [im_permission $user_id "add_hours"]
    if {!$add_hours & !$view_hours_all} { return "" }

    set hours_logged "<ul>"
    set info_html ""

    # fraber 2007-01-31: Admin doesn't make sense.
    if {$read && $view_ours_all_p} {
        set total_hours [im_timesheet_hours_sum -project_id $project_id]
	set total_hours_str "[util_commify_number $total_hours]"
        set info_html "[_ intranet-timesheet2.lt_A_total_of_total_hour]"
        if { $total_hours > 0 } {
           append hours_logged "
          <li>
            <a href=/intranet-timesheet2/hours/one-project?project_id=$project_id>
              [_ intranet-timesheet2.lt_See_the_breakdown_by_]
            </a>\n"
        }
#	append hours_logged "<li><a href=\"/intranet-timesheet2/weekly_report?project_id=$project_id\">[_ intranet-timesheet2.lt_View_hours_logged_by_]</a>"
    }

    if {$read} {
	set total_hours_str [im_timesheet_hours_sum -user_id $user_id -project_id $project_id]
        append info_html "<br>[_ intranet-timesheet2.lt_You_have_loged_total_].\n"
        set hours_today [im_timesheet_hours_sum -user_id $user_id -number_days 1]

	# Get the number of hours in the number of days, and whether
	# we should redirect if the user didn't log them...
	#
	set redirect_p [parameter::get -package_id [im_package_timesheet2_id] -parameter "TimesheetRedirectProjectIfEmptyHoursP" -default 0]
	set num_days [parameter::get -package_id [im_package_timesheet2_id] -parameter "TimesheetRedirectNumDays" -default 7]
	set expected_hours [parameter::get -package_id [im_package_timesheet2_id] -parameter "TimesheetRedirectNumHoursInDays" -default 32]
	set available_perc [util_memoize "db_string percent_available \"select availability from im_employees where employee_id = $user_id\" -default 100" 60]
	if {"" == $available_perc} { set available_perc 100 }
	set expected_hours [expr $expected_hours * $available_perc / 100]
        set num_hours [im_timesheet_hours_sum -user_id $user_id -number_days $num_days]
	if { $redirect_p && $num_hours < $expected_hours && $add_hours } {

            set default_message "
You have logged %num_hours% hours in the last %num_days% days.
However, you are expected to log atleast %expected_hours% hours
or an equivalent amount of absences.
Please log your hours now or consult with your supervisor."
	    set absences_hours_message ""
	    set header [lang::message::lookup "" intranet-timesheet2.Please_Log_Your_Hours "Please Log Your Hours"]
	    set message [lang::message::lookup "" intranet-timesheet2.You_need_to_log_hours $default_message]
	    ad_returnredirect [export_vars -base "/intranet-timesheet2/hours/index" {header message}]
	}

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



    # Add the <ul>-List of associated menus
    set start_date "2000-01-01"
    set end_date "2100-01-01"


    # show those menus from the Timesheet group ('reporting-timesheet-%')
    # that have a '?' in the URL, indicating that they take arguments.
    set menu_select_sql "
        select  m.*
        from    im_menus m
        where   label like 'reporting-timesheet-%'
		and position('?' in url) != 0
                and im_object_permission_p(m.menu_id, :user_id, 'read') = 't'
    "

    set menu_html "<ul>\n"
    set ctr 0
    db_foreach menu_select $menu_select_sql {
        regsub -all " " $name "_" name_key
	append url "project_id=$project_id&level_of_detail=3&start_date=$start_date&end_date=$end_date"
        append menu_html "<li><a href=\"$url\">[lang::message::lookup "" intranet-invoices.$name_key $name]</a></li>\n"
        incr ctr
    }
    append menu_html "</ul>\n"

    if {$ctr > 0} {
	append info_html "
		[lang::message::lookup "" intranet-timesheet2.Associated_reports "Associated Reports"]
		$menu_html
	"
    }

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
	im_category_from_id(absence_status_id) as absence_status,
        absence_id
from 
	im_user_absences
where 
	owner_id = :user_id
	and start_date <= to_date(:last_julian_date,'J')
	and end_date   >= to_date(:first_julian_date,'J')
    "


    # Initialize array with "" elements.
    for {set i $first_julian_date} {$i<=$last_julian_date} {incr i} {
	set vacation($i) ""
    }

    # Process vacation periods and modify array accordingly.
    db_foreach vacation_period $sql {
    
	set absence_status_3letter [string range $absence_status 0 2]
        set absence_status_3letter_l10n [lang::message::lookup "" intranet-timesheet2.Absence_status_3letter_$absence_status_3letter $absence_status_3letter]
	set absent_status_3letter_l10n $absence_status_3letter_l10n

	for {set i [max $start_date $first_julian_date]} {$i<=[min $end_date $last_julian_date]} {incr i } {
	   set vacation($i) "
<a href=\"/intranet-timesheet2/absences/new?form_mode=display&absence_id=$absence_id\"
>[_ intranet-timesheet2.Absent_1]</a> 
$absence_type<br>
           "
	}
    }
    # Return the relevant part of the array as a list.
    set result [list]
    for {set i $first_julian_date} {$i<=$last_julian_date} {incr i} {
	lappend result $vacation($i)
    }
    return $result
}


ad_proc im_timesheet_hours_sum { 
    {-user_id 0}
    {-project_id 0}
    {-number_days 0}
} {
    Returns the total number of hours the specified user logged for
    whatever else is included in the arg list.
} {
    # --------------------------------------------------------
    # Count the number of hours in the last days.

    if {0 != $user_id} {
	set criteria [list "user_id = :user_id"]
    }

    if {0 != $project_id} {
	lappend criteria "
		project_id in (
			select	children.project_id
			from	im_projects parent,
				im_projects children
			where
				children.tree_sortkey between 
					parent.tree_sortkey 
					and tree_right(parent.tree_sortkey)
				and parent.project_id = :project_id
		    UNION
			select	:project_id as project_id
		)
	"
    }

    if {0 != $number_days} {
	lappend criteria "day >= now()::date - $number_days"	
    }
    set num_hours [db_string sum_hours "
	select	sum(h.hours) 
	from	im_hours h
	where	
		h.day::date <= now()::date and
		[join $criteria "\n    and "]
    " -default 0]
    if {"" == $num_hours} { set num_hours 0}

    return $num_hours
}



ad_proc im_timesheet_absences_sum { 
    -user_id:required
    {-number_days 7} 
} {
    Returns the total number of absences multiplied by 8 hours per absence.
} {
    set hours_per_absence [parameter::get -package_id [im_package_timesheet2_id] -parameter "TimesheetHoursPerAbsence" -default 8]

    set num_absences [db_string absences_sum "
	select
		count(*)
	from
		im_user_absences a,
		im_day_enumerator(now()::date - '7'::integer, now()::date) d
	where
		owner_id = :user_id
		and a.start_date <= d.d
		and a.end_date >= d.d
    " -default 0]
    if {"" == $num_absences} { set num_absences 0}

    return [expr $num_absences * $hours_per_absence]
}


ad_proc im_timesheet_update_timesheet_cache {
    -project_id:required
} {
    Returns the total hours registered for the specified table and id.
} {
    set num_hours [im_timesheet_hours_sum -project_id $project_id]
    set cached_hours [db_string cached_hours "select reported_hours_cache from im_projects where project_id = :project_id" -default 0]

    # Update im_project reported_hours_cache
    if {$num_hours != $cached_hours} {
	db_dml update_project_reported_hours "
		update im_projects
		set reported_hours_cache = :num_hours
		where project_id = :project_id
	"
    }
    return $num_hours
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


# ---------------------------------------------------------------------
# Absence Workflow Permissions
#
# You can replace these functions with custom functions by modifying parameters.
# ---------------------------------------------------------------------


ad_proc im_absence_new_page_wf_perm_table { } {
    Returns a hash array representing (role x status) -> (v r d w a),
    controlling the read and write permissions on absences,
    depending on the users's role and the WF status.
} {
    set req [im_absence_status_requested]
    set rej [im_absence_status_rejected]
    set act [im_absence_status_active]
    set del [im_absence_status_deleted]

    set perm_hash(owner-$rej) {v r d w a}
    set perm_hash(owner-$req) {v r d}
    set perm_hash(owner-$act) {v r}
    set perm_hash(owner-$del) {v r}

    set perm_hash(assignee-$rej) {v r}
    set perm_hash(assignee-$req) {v r}
    set perm_hash(assignee-$act) {v r}
    set perm_hash(assignee-$del) {v r}

    set perm_hash(hr-$rej) {v r d w a}
    set perm_hash(hr-$req) {v r d w a}
    set perm_hash(hr-$act) {v r d w a}
    set perm_hash(hr-$del) {v r d w a}

    return [array get perm_hash]
}


ad_proc im_absence_new_page_wf_perm_edit_button {
    -absence_id:required
} {
    Should we show the "Edit" button in the AbsenceNewPage?
    The button is visible only for the Owner of the absence
    and the Admin, but nobody else during the course of the WF.
    Also, the Absence should not be changed anymore once it has
    started.
} {
    set perm_table [im_absence_new_page_wf_perm_table]
    set perm_set [im_workflow_object_permissions \
		    -object_id $absence_id \
		    -perm_table $perm_table
    ]

    ns_log Notice "im_absence_new_page_wf_perm_edit_button absence_id=$absence_id => $perm_set"
    return [expr [lsearch $perm_set "w"] > -1]
}

ad_proc im_absence_new_page_wf_perm_delete_button {
    -absence_id:required
} {
    Should we show the "Delete" button in the AbsenceNewPage?
    The button is visible only for the Owner of the absence,
    but nobody else in the WF.
} {
    set perm_table [im_absence_new_page_wf_perm_table]
    set perm_set [im_workflow_object_permissions \
		    -object_id $absence_id \
		    -perm_table $perm_table
    ]

    ns_log Notice "im_absence_new_page_wf_perm_delete_button absence_id=$absence_id => $perm_set"
    return [expr [lsearch $perm_set "d"] > -1]
}
