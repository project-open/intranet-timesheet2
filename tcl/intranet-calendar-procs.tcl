# /packages/intranet-timesheet2/tcl/intranet-calendar-procs.tcl
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
    reviewed by philg@mit.edu, June 1999 for release with ACS 2.0
    documentation and example in /www/doc/calendar-widget.html 
    smeeks@arsdigita.com, June 2000
    Added new widgets for new-calendar
    Documentation eventually in /www/doc/new-calendar-widgets.html
    
    @author Greg Haverkamp (gregh@arsdigita.com)
    @creation-date June 1999
    @cvs-id ad-calendar-widget.tcl,v 3.11.2.6 2000/09/14 07:36:27 ron Exp
}


ad_proc calendar_get_info_from_db {
    { the_date "" }
} {
    Calculates various dates required by the calendar_basic_month
    procedure. Defines, in the caller's environment, a whole set of
    variables needed for calendar display.
    
    @param the_date If set in "YYYY-MM-DD" format, information for the specified date is used. Defaults to trunc(sysdate)

    @author Greg Haverkamp (gregh@arsdigita.com)
    
} {

    # If no date was passed in, let's set it to today
    if { $the_date == "" } {
	set the_date [db_string sysdate_from_dual "select trunc(sysdate) from dual"]
    }

    # This query gets us all of the date information we need to calculate
    # the calendar, including the name of the month, the year, the julian date
    # of the first of the month, the day of the week of the first day of the
    # month, the day number of the last day (28, 29, 30 ,31) and
    # a month string of the next and previous months
    set month_info_query "
	select	to_char(trunc(to_date(:the_date, 'yyyy-mm-dd'), 'Month'), 'fmMonth') as month, 
		to_char(trunc(to_date(:the_date, 'yyyy-mm-dd'), 'Month'), 'YYYY') as year, 
		to_char(trunc(to_date(:the_date, 'yyyy-mm-dd'), 'Month'), 'J') as first_julian_date_of_month, 
		to_char(last_day(to_date(:the_date, 'yyyy-mm-dd')), 'DD') as num_days_in_month,
		to_char(trunc(to_date(:the_date, 'yyyy-mm-dd'), 'Month'), 'D') as first_day_of_month, 
		to_char(last_day(to_date(:the_date, 'yyyy-mm-dd')), 'DD') as last_day,
		trunc(add_months(to_date(:the_date, 'yyyy-mm-dd'), 1),'Day') as next_month,
    		trunc(add_months(to_date(:the_date, 'yyyy-mm-dd'), -1),'Day') as prev_month,
    		trunc(to_date(:the_date, 'yyyy-mm-dd'), 'year') as beginning_of_year,
    		to_char(last_day(add_months(to_date(:the_date, 'yyyy-mm-dd'), -1)), 'DD') as days_in_last_month,
    		to_char(add_months(to_date(:the_date, 'yyyy-mm-dd'), 1), 'fmMonth') as next_month_name,
    		to_char(add_months(to_date(:the_date, 'yyyy-mm-dd'), -1), 'fmMonth') as prev_month_name
    	from dual
    "

    # We put all the columns into calendar_info_set and return it later
    set calendar_info_set [ns_set create]

    set bind_vars [ad_tcl_vars_to_ns_set the_date]
    db_1row calendar_get_information $month_info_query -bind $bind_vars -column_set calendar_info_set
    ns_set free $bind_vars

    # We need the variables from the select query here as well
    ad_ns_set_to_tcl_vars $calendar_info_set

    ns_set put $calendar_info_set first_julian_date \
        [expr $first_julian_date_of_month + 1 - $first_day_of_month]

    ns_set put $calendar_info_set first_day \
        [expr $days_in_last_month + 2 - $first_day_of_month]

    ns_set put $calendar_info_set last_julian_date_in_month \
        [expr $first_julian_date_of_month + $num_days_in_month - 1]

    set days_in_next_month [expr 7 - (($num_days_in_month + $first_day_of_month - 1) % 7)]

    if {$days_in_next_month == 7} {
        set days_in_next_month 0
    }

    ns_set put $calendar_info_set last_julian_date \
	    [expr $first_julian_date_of_month + $num_days_in_month - 1 + $days_in_next_month]


    # Now, set the variables in the caller's environment
    ad_ns_set_to_tcl_vars -level 2 $calendar_info_set
    ns_set free $calendar_info_set
}


proc_doc calendar_convert_julian_to_ansi { 
    julian_date 
} {
    Return an ANSI date for a Julian date
} {
    im_security_alert_check_integer -location "calendar_convert_julian_to_ansi" -value $julian_date
    set output [util_memoize [list db_string julian_date_trunc "select to_char(to_date('$julian_date', 'J'), 'YYYY-MM-DD')"]]
    return $output
}

ad_proc calendar_basic_month { 
    { 
	-calendar_details "" 
	-date "" 
	-days_of_week "Sunday Monday Tuesday Wednesday Thursday Friday Saturday" 
	-large_calendar_p 1 
	-master_bgcolor "black" 
	-header_bgcolor "black"
	-header_text_color "white"
	-header_text_size "+2"
	-day_number_template {<!--$julian_date--><span class='day_number'>$day_number</span>}
	-day_header_size 2
	-day_header_bgcolor "#666666"
	-calendar_width "100%"
	-day_bgcolor "#DDDDDD"
	-today_bgcolor "#DDDDDD"
	-day_text_color "white"
	-empty_bgcolor "white" 
	-next_month_template ""  
	-prev_month_template ""
	-prev_next_links_in_title 0
	-fill_all_days 0 } 
} "
Returns a calendar for a specific month, with details supplied 
by Julian date. Defaults to this month.
To specify details for the individual days (if large_calendar_p is set) 
put data in an ns_set calendar_details.  The key is the Julian date of 
the day, and the value is a string (possibly with HTML formatting) that 
represents the details.
" {
    calendar_get_info_from_db $date
    set todays_date [lindex [split [ns_localsqltimestamp] " "] 0]

    if { $calendar_details == "" } {
	set calendar_details [ns_set create calendar_details]
    }

    set day_of_week $first_day_of_month


    set julian_date $first_julian_date

    set month_heading [format "%s %s" [_ intranet-timesheet2.$month] $year]
    set next_month_url ""
    set prev_month_url ""

    if { $prev_month_template != "" } { 
	set ansi_date [ns_urlencode $prev_month]
	set prev_month_url [subst $prev_month_template]
    }
    if { $next_month_template != "" } {
	set ansi_date [ns_urlencode $next_month]
	set next_month_url [subst $next_month_template]
    }

    # We offer an option to put the links to next and previous months in the title bar
    if { $prev_next_links_in_title == 0 } {
	set title "<td colspan=7 align=center>$month_heading></td>"
    } else {
	set title "
<td colspan=7>
  <table id='month_header' class='month_header' width='100%'>
  <tr>
    <td align=left>$prev_month_url</td>
    <td align=center><a href=\"\">$month_heading</a></td>
    <td align=right>$next_month_url</td>
  </tr>
  </table>
</td>
"
    }

    # Write out the header and the days of the week
    append output "<table id='calendar_table' class='calendar_table' bgcolor=$master_bgcolor cellpadding=3 cellspacing=1 border=0>
    <tr class='month_heading' bgcolor=$header_bgcolor>
    $title
    </tr>
    <tr class='day_header'>"

    foreach day_of_week $days_of_week {
	append output "<td width=14% align=center>$day_of_week</td>"
    }

    append output "</tr><tr>"

    if { $fill_all_days == 0 } {
	for { set n 1} { $n < $first_day_of_month } { incr n } {
	    append output "<td id='empty_bg' bgcolor=$empty_bgcolor align=right valign=top></td>"
	}
    }

    set day_of_week 1
    set julian_date $first_julian_date
    set day_number $first_day

    while {1} {

        if {$julian_date < $first_julian_date_of_month} {
            set before_month_p 1
            set after_month_p 0
        } elseif {$julian_date > $last_julian_date_in_month} {
            set before_month_p 0
            set after_month_p 1
        } else {
            set before_month_p 0
            set after_month_p 0
        }

        if {$julian_date == $first_julian_date_of_month} {
            set day_number 1
        } elseif {$julian_date > $last_julian_date} {
            break
        } elseif {$julian_date == [expr $last_julian_date_in_month +1]} {
            set day_number 1
        }

	if { $day_of_week == 1} {
	    append output "\n<tr>\n"
	}

	set skip_day 0
	if {$before_month_p || $after_month_p} {
	    append output "<td class='before_after_month' bgcolor=$empty_bgcolor align=right valign=top>&nbsp;"
	    if { $fill_all_days == 0 } {
		set skip_day 1
	    } else {
		append output "[subst $day_number_template]&nbsp;"
	    }
	} else {

            # We are within the normal day of the month.
            set day_ansi [calendar_convert_julian_to_ansi $julian_date]

            ns_log Notice "calendar_basic_month: '$todays_date', '$day_ansi'"

	    set weekend ""
	    if { "1" == $day_of_week || "7" == $day_of_week } {
		set weekend "_weekend" 
	    }  

            if {[string equal $todays_date $day_ansi]} {
               
	        append output "<td class='todays_date$weekend' bgcolor=#6699CC align=right valign=top>[subst $day_number_template]&nbsp;"

            } else {

	        append output "<td class='not_todays_date$weekend' bgcolor=$day_bgcolor align=right valign=top>[subst $day_number_template]&nbsp;"

            }

	}

	if { (! $skip_day) && $large_calendar_p == 1 } {
	    append output "<div class='link_log_hours' align=left>"

	    set calendar_day_index [ns_set find $calendar_details $julian_date]
	    
	    while { $calendar_day_index >= 0 } {
		    
		set calendar_day [ns_set value $calendar_details $calendar_day_index]
		ns_set delete $calendar_details $calendar_day_index
		
		append output "$calendar_day"
		
		set calendar_day_index [ns_set find $calendar_details $julian_date]
		
	    }
	    
	    append output "</div>"
	}

	append output "</td>\n"

	incr day_of_week
	incr julian_date
        incr day_number

	if { $day_of_week > 7 } {
	    set day_of_week 1
	    append output "</tr>\n"
	}
    }

    # There are two ways to display previous and next month link - this is the default
    if { $prev_next_links_in_title == 0 } {
	append output "
    <tr class='prev_next_month'>
    <td align=center colspan=7>$prev_month_url$next_month_url</td>
    </tr>"
    }

    append output "</table>"

    return $output

}

ad_proc calendar_small_month { {
    -calendar_details ""
    -date ""
    -days_of_week "S M T W T F S"
    -large_calendar_p 0
    -master_bgcolor "black"
    -header_bgcolor "black"
    -header_text_color "white"
    -header_text_size "+1"
    -day_number_template {<!--$julian_date--><span class='day_number'>$day_number</span>}
    -day_header_size 1
    -day_header_bgcolor "#666666"
    -calendar_width 0
    -day_bgcolor "#DDDDDD"
    -day_text_color "white"
    -empty_bgcolor "white" 
    -next_month_template ""  
    -prev_month_template ""  } } "Returns a small calendar for a specific month. Defaults to this month." {

    return [calendar_basic_month -calendar_details $calendar_details -date $date -days_of_week $days_of_week -large_calendar_p $large_calendar_p -master_bgcolor $master_bgcolor -header_bgcolor $header_bgcolor -header_text_color $header_text_color -header_text_size $header_text_size -day_number_template $day_number_template -day_header_size $day_header_size -day_header_bgcolor $day_header_bgcolor -calendar_width $calendar_width -day_bgcolor $day_bgcolor -day_text_color $day_text_color -empty_bgcolor $empty_bgcolor  -next_month_template $next_month_template   -prev_month_template $prev_month_template ]

}

ad_proc calendar_prev_current_next { {
    -calendar_details ""
    -date ""
    -days_of_week "S M T W T F S"
    -large_calendar_p 0
    -master_bgcolor "black"
    -header_bgcolor "black"
    -header_text_color "white"
    -header_text_size "+1"
    -day_number_template {<!--$julian_date--><span class='day_number'>$day_number</span>}
    -day_header_size 1
    -day_header_bgcolor "#666666"
    -calendar_width 0
    -day_bgcolor "#DDDDDD"
    -day_text_color "white"
    -empty_bgcolor "white" 
    -next_month_template ""  
    -prev_month_template ""  } } "Returns a calendar for a specific month, with details supplied by Julian date. Defaults to this month." {

    set output ""

    calendar_get_info_from_db $date

    append output "<table><tr valign=top>\n"
    append output "<td>
    [calendar_small_month -calendar_details $calendar_details -date $prev_month -days_of_week $days_of_week -large_calendar_p $large_calendar_p -master_bgcolor $master_bgcolor -header_bgcolor $header_bgcolor -header_text_color $header_text_color -header_text_size $header_text_size -day_number_template $day_number_template -day_header_size $day_header_size -day_header_bgcolor $day_header_bgcolor -calendar_width $calendar_width -day_bgcolor $day_bgcolor -day_text_color $day_text_color -empty_bgcolor $empty_bgcolor  -next_month_template $next_month_template   -prev_month_template $prev_month_template ]</td>
    <td>
    [calendar_small_month -calendar_details $calendar_details -date $date -days_of_week $days_of_week -large_calendar_p $large_calendar_p -master_bgcolor $master_bgcolor -header_bgcolor $header_bgcolor -header_text_color $header_text_color -header_text_size $header_text_size -day_number_template $day_number_template -day_header_size $day_header_size -day_header_bgcolor $day_header_bgcolor -calendar_width $calendar_width -day_bgcolor $day_bgcolor -day_text_color $day_text_color -empty_bgcolor $empty_bgcolor  -next_month_template $next_month_template   -prev_month_template $prev_month_template ]
    </td>
    <td>
    [calendar_small_month -calendar_details $calendar_details -date $next_month -days_of_week $days_of_week -large_calendar_p $large_calendar_p -master_bgcolor $master_bgcolor -header_bgcolor $header_bgcolor -header_text_color $header_text_color -header_text_size $header_text_size -day_number_template $day_number_template -day_header_size $day_header_size -day_header_bgcolor $day_header_bgcolor -calendar_width $calendar_width -day_bgcolor $day_bgcolor -day_text_color $day_text_color -empty_bgcolor $empty_bgcolor  -next_month_template $next_month_template   -prev_month_template $prev_month_template ]
    </td>
    </table>\n"

    return $output
}

ad_proc calendar_small_year { {-calendar_details "" -date "" -days_of_week "S M T W T F S" -large_calendar_p 0 -master_bgcolor "black" -header_bgcolor "black" -header_text_color "white" -header_text_size "+1" -day_number_template {<!--$julian_date--><span class='day_number'>$day_number</span>} -day_header_size 1 -day_header_bgcolor "#666666" -calendar_width 0 -day_bgcolor "#DDDDDD" -day_text_color "white" -empty_bgcolor "white"  -next_month_template ""   -prev_month_template ""  -width 2} } "Returns a year of small calendars given the starting month as a date.  Defaults to this month.  Data in calendar_details will be ignored." {

    if { $width < 1 || $width > 12 } {
	return "Width must be between 1 and 12"
    }

    set output "<table><tr valign=top>\n"
    set current_width 0

    for { set n 1 } { $n <= 12 } { incr n } {
	set selection [calendar_get_info_from_db $date]
	set_variables_after_query
	
	append output "<td>"

	append output "[calendar_small_month -calendar_details $calendar_details -date $date -days_of_week $days_of_week -large_calendar_p $large_calendar_p -master_bgcolor $master_bgcolor -header_bgcolor $header_bgcolor -header_text_color $header_text_color -header_text_size $header_text_size -day_number_template $day_number_template -day_header_size $day_header_size -day_header_bgcolor $day_header_bgcolor -calendar_width $calendar_width -day_bgcolor $day_bgcolor -day_text_color $day_text_color -empty_bgcolor $empty_bgcolor  -next_month_template $next_month_template   -prev_month_template $prev_month_template ]"
	append output "</td>\n"

	incr current_width

	if { $current_width == $width && $n != 12} {
	    set current_width 0
	    append output "</tr><tr valign=top>\n"
	}

	set date $next_month
    }

    append output "</tr></table>\n"

    return $output
}

ad_proc calendar_small_calendar_year { {-calendar_details "" -date "" -days_of_week "S M T W T F S" -large_calendar_p 0 -master_bgcolor "black" -header_bgcolor "black" -header_text_color "white" -header_text_size "+1" -day_number_template {<!--$julian_date--><span class=day_number>$day_number</span>} -day_header_size 1 -day_header_bgcolor "#666666" -calendar_width 0 -day_bgcolor "#DDDDDD" -day_text_color "white" -empty_bgcolor "white" -next_month_template "" -prev_month_template "" -width 2} } "Returns a calendar year of small calendars for the year of the passed in date.  Defaults to this year." {

    calendar_get_info_from_db $date

    return [calendar_small_year -calendar_details $calendar_details -date $beginning_of_year -days_of_week $days_of_week -large_calendar_p $large_calendar_p -master_bgcolor $master_bgcolor -header_bgcolor $header_bgcolor -header_text_color $header_text_color -header_text_size $header_text_size -day_number_template $day_number_template -day_header_size $day_header_size -day_header_bgcolor $day_header_bgcolor -calendar_width $calendar_width -day_bgcolor $day_bgcolor -day_text_color $day_text_color -empty_bgcolor $empty_bgcolor  -next_month_template $next_month_template  -prev_month_template $prev_month_template  -width $width]
}

ad_proc mini_calendar_widget { 
    {} {base_url ""} {current_view ""} {current_date ""} {group_id 0} {pass_in_vars ""} } {
	"This proc creates a mini calendar useful for navigating various 
	calendar views.  It takes a base url, which is the url to which this 
	mini calendar will navigate.  pass_in_vars, if defined, can be
	url variables to be set in base_url.  They should be in the format
	returned by export_url_vars
	This proc will set 2 variables in that
	url's environment: the current view and the current date.  Valid views 
	are list, day, week, month, and year.  
	The current_date must be formatted YYYY-MM-DD."} {
    #valid views are "list" "day" "week" "month" "year"
    if {![exists_and_not_null current_view]} {
	set current_view "week"
    }

    if {![exists_and_not_null base_url]} {
	set base_url [ns_conn url]
    }

    if {[exists_and_not_null pass_in_vars]} {
	append base_url "?$pass_in_vars&"
    } else {
	append base_url "?"
    }

    if {![exists_and_not_null current_date]} {
	set current_date [db_string sysdate_from_dual "select
	sysdate from dual"]
    }

    #get the current month, day, and the first day of the month
    set bind_vars [ad_tcl_vars_to_ns_set current_date]
    db_1row calendar_get_month_info "select
    trim(to_char(sysdate, 'Month')) || ' ' || to_char(sysdate, 'DD, YYYY') as pretty_today,
    trim(to_char(month.current_month, 'Month')) as this_month,
    sysdate as today,
    to_char(next_year.year, 'YYYY') as next_year_year,
    next_year.year as next_year,
    to_char(prev_year.year, 'YYYY') as prev_year_year,
    prev_year.year as prev_year,
    next_month.month as next_month,
    prev_month.month as prev_month,
    to_char(next_month.month, 'YYYY') as next_month_year,
    to_char(next_month.month, 'MM') as next_month_month,
    to_char(next_month.month, 'DD') as next_month_day,
    to_char(prev_month.month, 'YYYY') as prev_month_year,
    to_char(prev_month.month, 'MM') as prev_month_month,
    to_char(prev_month.month, 'DD') as prev_month_day,
    month.current_month,
    to_char(month.current_month, 'MM') as current_month_num,
    to_char(day.current_day, 'dd') as current_day,
    to_char(day.current_day, 'YYYY') as current_year,
    to_char(trunc(month.current_month, 'DD'), 'fmDay') as month_start,
    to_char(last_day(month.current_month), 'dd') as last_day,
    trim(to_char(month.current_month, 'Month')) || ' ' || trim(to_char(month.current_month, 'YYYY')) as pretty_month,
    to_char(last_day(add_months(trunc(month.current_month, 'DD'),-1 )), 'dd') as prev_month_last_day
    from
    (select
    add_months(:current_date, 12) as year
    from dual) next_year,
    (select 
    add_months(:current_date, -12) as year
    from dual) prev_year,
    (select
    add_months(:current_date, 1) as month
    from dual) next_month,
    (select
    add_months(:current_date, -1) as month
    from dual) prev_month,
    (select trunc(to_date(:current_date), 'Month')
     as current_month
     from dual) month,
    (select trunc(to_date(:current_date), 'DD')
     as current_day
     from dual) day" -bind $bind_vars
    ns_set free $bind_vars

    #detect which view I'm in and show the appropriate box
    set view_nav_html ""
    append view_nav_html "
    <tr align=center>    
     [ad_decode $current_view "list" "<td BGCOLOR=FFD700>" "<td>"]    
    <a href=\"$base_url" "current_view=list&current_date=[ns_urlencode $current_date]&group_id=$group_id\">
    <font size=-1 color=blue>List</font></a>
    </td>
     [ad_decode $current_view "day" "<td BGCOLOR=FFD700>" "<td>"]    
    <a href=\"$base_url" "current_view=day&current_date=[ns_urlencode $current_date]&group_id=$group_id\">
    <font size=-1 color=blue>Day</font></a>
    </td>
     [ad_decode $current_view "week" "<td BGCOLOR=FFD700>" "<td>"]
    <a href=\"$base_url" "current_view=week&current_date=[ns_urlencode $current_date]&group_id=$group_id\">
    <font size=-1 color=blue>Week</font></a>
    </td>
     [ad_decode $current_view "month" "<td BGCOLOR=FFD700>" "<td>"]    
    <a href=\"$base_url" "current_view=month&current_date=[ns_urlencode $current_date]&group_id=$group_id\">
    <font size=-1 color=blue>Month</font></a>
    </td>
     [ad_decode $current_view "year" "<td BGCOLOR=FFD700>" "<td>"]
    <a href=\"$base_url" "current_view=year&current_date=[ns_urlencode $current_date]&group_id=$group_id\">
    <font size=-1 color=blue>Year</a>
    </td>
    </tr>
    "

    set return_html "
    <table border=1 cellpadding=1 cellspacing=0 width=160>

    $view_nav_html
    "

    #if this is a month or year view, show the current year in the main bar
    if {([string compare $current_view "month"] == 0) || ([string compare $current_view "year"] == 0)} {
		append return_html "
	<tr><TD NOWRAP ALIGN=CENTER bgcolor=lavender colspan=5>
	<TABLE CELLSPACING=0 CELLPADDING=1 BORDER=0>
	<tr><td NOWRAP VALIGN=middle>
        <a href=\"$base_url" "current_view=$current_view&current_date=[ns_urlencode $prev_year]&group_id=$group_id\">
        <img border=0 src=\"/graphics/left.gif\"></a>
        <TT><B>$current_year</B></TT>
	<a href=\"$base_url" "current_view=$current_view&current_date=[ns_urlencode $next_year]&group_id=$group_id\">
        <img border=0 src=\"/graphics/right.gif\"></a>
        </td>
	</tr>
	</table>
	</TD></tr>"
    }

    if {[string compare $current_view "month"] == 0} {
	#month view
	append return_html "
	<tr><td colspan=5>
	<TABLE BGCOLOR=ffffff CELLSPACING=3 CELLPADDING=1 BORDER=0>
	<tr>
	"

	set months_list [list January February March April May June July August September October November December]
	set i 0
	while {$i < 12} {
	    set month [lindex $months_list $i]

	    #show 3 months in a row
	    if {([expr int(fmod($i, 3))] == 0) && ($i != 0)} {
		append return_html "</tr><tr>"
	    }
	    
	    if {[string compare $month $this_month] == 0} {
		append return_html "
		<td>
		<font size=-1 color=red>$month</font>
		</td>
		"
	    } else {
		set new_month_mon "[expr $i + 1]"
		if {[string length $new_month_mon] == 1} {
		    set new_month_mon "0$new_month_mon"
		} 
		set new_month "$current_year-$new_month_mon-$current_day"
		set month_link ""
		append month_link "
		<a href=\"$base_url" "current_view=$current_view&current_date=[ns_urlencode $new_month]&group_id=$group_id\">
		<font size=-1 color=blue>$month</font></a>"

		append return_html "<td>$month_link</td>"
	    }
	
	    incr i	    
	}
	
	append return_html "</tr>"	    

	
    } elseif {[string compare $current_view "year"] == 0} {
	#year view
	append return_html "
	<tr><td colspan=5>
	<TABLE BGCOLOR=ffffff CELLSPACING=3 CELLPADDING=1 BORDER=0>
	<tr>
	"

	set i [expr $current_year - 2]
	set end_year [expr $current_year + 2]
	set count 0

	while {$i <= $end_year} {
	    
	    if {[string compare $i $current_year] == 0} {
		append return_html "
		<td>
		<font size=-1 color=red>$i</font>
		</td>
		"
	    } else {
		set new_year "$i-$current_month_num-$current_day"
		append return_html "
		<td>
		<a href=\"$base_url" "current_view=$current_view&current_date=[ns_urlencode $new_year]&group_id=$group_id\"><font size=-1 color=blue>$i</font></a></td>"

	    }

	    incr count	    
	    incr i
	}
	
	append return_html "</tr>"
	
    } else {
	#list, day, week view
	append return_html "
	<tr><TD NOWRAP ALIGN=CENTER bgcolor=lavender colspan=5>
	<TABLE CELLSPACING=0 CELLPADDING=1 BORDER=0>
	<tr><td NOWRAP VALIGN=middle>
        <a href=\"$base_url" "current_view=$current_view&current_date=[ns_urlencode $prev_month]&group_id=$group_id\">
        <img border=0 src=\"/graphics/left.gif\"></a>
        <TT><B>$pretty_month</B></TT>
	<a href=\"$base_url" "current_view=$current_view&current_date=[ns_urlencode $next_month]&group_id=$group_id\">
        <img border=0 src=\"/graphics/right.gif\"></a>
        </td>
	</tr>
	</table>
	</TD></tr>

	<tr><td colspan=5>
	<TABLE BGCOLOR=ffffff CELLSPACING=3 CELLPADDING=1 BORDER=0>
	"

	#get all the sundays then all the mondays, etc
	#and puts <br> tags between the dates

	#make a week list so that I can translate days into numbers (with lindex)
	set week_list [list "Sunday" "Monday" "Tuesday" "Wednesday" "Thursday" "Friday" "Saturday"]
	
	#map indices from week_list to the lists below
	set week_map [list "sundays" "mondays" "tuesdays" "wednesdays" "thursdays" "fridays" "saturdays"]

	#these lists hold their respective dates.  So, sundays holds the dates of
	#all the sundays in the month
	set sundays "<td align=right><font size=-1><b>Su</b>"
	set mondays "<td align=right><font size=-1><b>Mo</b>"
	set tuesdays "<td align=right><font size=-1><b>Tu</b>"
	set wednesdays "<td align=right><font size=-1><b>We</b>"
	set thursdays "<td align=right><font size=-1><b>Th</b>"
	set fridays "<td align=right><font size=-1><b>Fr</b>"
	set saturdays "<td align=right><font size=-1><b>Sa</b>"

	#Use the first day of the month and assign 1 to its list.
	#For all the days before that day, pad the first index
	#with days from the last month.
	#Then, fill in all the rest of the lists

	set first_day_index [lsearch -exact $week_list $month_start]

	set pad_index $first_day_index
	while {$pad_index > 0} {
	    #pad the lists with days from the last month as necessary
	    set pad_index [expr $pad_index -1]

	    set day_list [lindex $week_map $pad_index]

	    set day_date "$prev_month_year-"
	    append day_date "$prev_month_month-"
	    if {[string length $prev_month_last_day] == 1} {
		append day_date "0$prev_month_last_day"
	    } else {
		append day_date "$prev_month_last_day"
	    }
	    set day_date_link ""
	    append day_date_link "<a href=\"$base_url" "current_view=$current_view&current_date=[ns_urlencode $day_date]&group_id=$group_id\"><font color=gray>$prev_month_last_day</font></a>"

	    append $day_list "<br>$day_date_link"

	    set prev_month_last_day [expr $prev_month_last_day - 1]
	}

	set i 1
	#we want to use 1-based indexing for the day_index so that we
	#can distinguish the first and last day of the week using the
	#mod function.
	set day_index [expr $first_day_index +1]
	while {$i <= $last_day} {
	    #fill in the lists
	    
	    #convert day_index back to 0-based indexing for lindex
	    set day_list [lindex $week_map [expr $day_index - 1]]

	    set day_date "$current_year-"
	    append day_date "$current_month_num-"
	    if {[string length $i] == 1} {
		append day_date "0$i"
	    } else {
		append day_date "$i"
	    }

	    set day_date_link ""
	    append day_date_link "<a href=\"$base_url" "current_view=$current_view&current_date=[ns_urlencode $day_date]&group_id=$group_id\"><font color=blue>$i</font></a>"

	    if {$i == $current_day} {
		#this is the current day, so format it differently
		append $day_list "<br><b><font color=red>$i</font></b>"
	    } else {
		append $day_list "<br>$day_date_link"
	    }

	    incr i

	    set day_index [expr int(fmod($day_index+1, 7))]
	    if {$day_index == 0} {
		set day_index 7
	    }

	}   

	#special case: if day_index is 1, then the last day
	#was saturday since day_index was updated at the end
	#of the while loop.  So, we don't want to fill
	#in the rest of the week
	if {$day_index == 1} {
	    set day_index 8
	}


	#pad the rest of the weekdays with dates from the following month
	set i 1
	while {$day_index <= 7} {
	    set day_list [lindex $week_map [expr $day_index - 1]]

	    set day_date "$next_month_year-"
	    append day_date "$next_month_month-"
	    if {[string length $i] == 1} {
		append day_date "0$i"
	    } else {
		append day_date "$i"
	    }
	    set day_date_link ""
	    append day_date_link "<a href=\"$base_url" "current_view=$current_view&current_date=[ns_urlencode $day_date]&group_id=$group_id\"><font color=gray>$i</font></a>"

	    append $day_list "<br>$day_date_link"
	    incr day_index
	    incr i
	}

	#close the weekday lists
	set i 0
	while {$i < 7} {
	    set day_list [lindex $week_map $i]
	    append $day_list "</font></td>\n"
	    incr i
	}

	append return_html "<tr valign=top>" $sundays $mondays $tuesdays $wednesdays $thursdays $fridays $saturdays "</tr>"

    }
    set today_url ""
    append today_url "$base_url" "current_view=day&current_date=[ns_urlencode $today]&group_id=$group_id"

    append return_html "
    <tr><td align=center colspan=7>
    <table cellspacing=0 cellpadding=1 border=0>
    <tr><td>
    <form method=get action=\"$base_url\">
    [philg_hidden_input current_view $current_view]
    [philg_hidden_input group_id $group_id]
    <center>
    <font size=-1>
    <input type=text size=10 name=current_date value=\"$current_date\">
    <input type=submit value=\"Go\"><br>
    (YYYY-MM-DD Format)
    </font>
    </center>
    </form>
    </td></tr>
    </table>
    </td></tr>

    </table>
    </td></tr>
    
    <tr><td align=center bgcolor=lavender colspan=5>
    <TABLE CELLSPACING=0 CELLPADDING=1 BORDER=0 bgcolor=lavender>
    <td><td>
     <font size=-1><a href=\"$today_url\"><font color=blue><b>Today</b></font></a>
    is $pretty_today</font></td>
    </td></tr>
    </table>
    </td></tr>

    </table>
    "

    return $return_html
   
}

proc mini_month_calendar {current_year month {group_id 0}} {

    #month is the 'MM' form of the current month
    #current_date is 'YYYY' format of current year
     
    set month_txt "$current_year-$month-01"

    set bind_vars [ad_tcl_vars_to_ns_set month_txt]
    db_1row month_get_info "select
    to_char(to_date(:month_txt), 'fmMonth') as this_month,
    to_char(last_day(to_date(:month_txt)), 'dd') as last_day,
    to_char(to_date(:month_txt), 'MM') as current_month_num,
    to_char(trunc(to_date(:month_txt), 'DD'), 'fmDay') as month_start,
    to_char(to_date(:month_txt), 'fmMonth') as this_month,
    to_char(add_months(to_date(:month_txt), 1), 'MM') as next_month_month,
    to_char(add_months(to_date(:month_txt), 1), 'YYYY') as next_month_year,
    to_char(last_day(add_months(to_date(:month_txt), -1)), 'dd') as prev_month_last_day,
    to_char(add_months(to_date(:month_txt), -1), 'YYYY') as prev_month_year,
    to_char(add_months(to_date(:month_txt), -1), 'MM') as prev_month_month
    from dual
    "  -bind $bind_vars
    ns_set free $bind_vars

    set return_html "
    <table border=1 cellpadding=1 cellspacing=0 >
    <tr align=center bgcolor=lavender>
    <td colspan=7>
    <a href=\"?group_id=$group_id&current_view=month&current_date=$month_txt\">
    $this_month</a>
    </td>
    </tr>
    <tr>
    <td>
    <TABLE CELLSPACING=3 CELLPADDING=1 BORDER=0 width=100%>
    "
    
    
    #get all the sundays then all the mondays, etc
    #and puts <br> tags between the dates
    
    #make a week list so that I can translate days into numbers (with lindex)
    set week_list [list "Sunday" "Monday" "Tuesday" "Wednesday" "Thursday" "Friday" "Saturday"]
    
    #map indices from week_list to the lists below
    set week_map [list "sundays" "mondays" "tuesdays" "wednesdays" "thursdays" "fridays" "saturdays"]

    #these lists hold their respective dates.  So, sundays holds the dates of
    #all the sundays in the month
    set sundays "<td align=right><font size=-1><b>Su</b>"
    set mondays "<td align=right><font size=-1><b>Mo</b>"
    set tuesdays "<td align=right><font size=-1><b>Tu</b>"
    set wednesdays "<td align=right><font size=-1><b>We</b>"
    set thursdays "<td align=right><font size=-1><b>Th</b>"
    set fridays "<td align=right><font size=-1><b>Fr</b>"
    set saturdays "<td align=right><font size=-1><b>Sa</b>"

    #Use the first day of the month and assign 1 to its list.
    #For all the days before that day, pad the first index
    #with days from the last month.
    #Then, fill in all the rest of the lists

    set first_day_index [lsearch -exact $week_list $month_start]

    set pad_index $first_day_index
    while {$pad_index > 0} {
	#pad the lists with days from the last month as necessary
	set pad_index [expr $pad_index -1]

	set day_list [lindex $week_map $pad_index]

	set day_date "$prev_month_year-"
	append day_date "$prev_month_month-"
	if {[string length $prev_month_last_day] == 1} {
	    append day_date "0$prev_month_last_day"
	} else {
	    append day_date "$prev_month_last_day"
	}
	set day_date_link "<a href=\"?group_id=$group_id&current_view=day&current_date=[ns_urlencode $day_date]\"><font color=gray>$prev_month_last_day</font></a>"

	append $day_list "<br>$day_date_link"

	set prev_month_last_day [expr $prev_month_last_day - 1]
    }

    set i 1
    #we want to use 1-based indexing for the day_index so that we
    #can distinguish the first and last day of the week using the
    #mod function.
    set day_index [expr $first_day_index +1]
    while {$i <= $last_day} {
	#fill in the lists
	
	#convert day_index back to 0-based indexing for lindex
	set day_list [lindex $week_map [expr $day_index - 1]]

	set day_date "$current_year-"
	append day_date "$current_month_num-"
	if {[string length $i] == 1} {
	    append day_date "0$i"
	} else {
	    append day_date "$i"
	}

	set day_date_link "<a href=\"?group_id=$group_id&current_view=day&current_date=[ns_urlencode $day_date]\"><font color=blue>$i</font></a>"

	append $day_list "<br>$day_date_link"

	incr i

	set day_index [expr int(fmod($day_index+1, 7))]
	if {$day_index == 0} {
	    set day_index 7
	}

    }   

    #special case: if day_index is 1, then the last day
    #was saturday since day_index was updated at the end
    #of the while loop.  So, we don't want to fill
    #in the rest of the week
    if {$day_index == 1} {
	set day_index 8
    }

    #pad the rest of the weekdays with dates from the following month
    set i 1
    while {$day_index <= 7} {
	set day_list [lindex $week_map [expr $day_index - 1]]

	set day_date "$next_month_year-"
	append day_date "$next_month_month-"
	if {[string length $i] == 1} {
	    append day_date "0$i"
	} else {
	    append day_date "$i"
	}
	set day_date_link "<a href=\"?group_id=$group_id&current_view=day&current_date=[ns_urlencode $day_date]\"><font color=gray>$i</font></a>"

	append $day_list "<br>$day_date_link"
	incr day_index
	incr i
    }

    #see if we need to add an extra row to the calendar
    set first_day_index [lsearch -exact $week_list $month_start]
    if {$first_day_index != 0} {
	#this is the date of the first sunday
	set first_sun [expr 8 - $first_day_index]
	set extra_week 1
    } else {
	set first_sun 1
	set extra_week 0
    }
    set num_weeks [expr int(ceil(double($last_day+1-$first_sun)/double(7)) + $extra_week)]
    if {$num_weeks < 6} {
	set i 0
	while {$i < 7} {
	    set day_list [lindex $week_map $i]
	    append $day_list "<br>&nbsp"
	    incr i
	}
    }


    #close the weekday lists
    set i 0
    while {$i < 7} {
	set day_list [lindex $week_map $i]
	append $day_list "</font></td>\n"
	incr i
    }

   

    append return_html "<tr valign=top>" $sundays $mondays $tuesdays $wednesdays $thursdays $fridays $saturdays "</tr></table></td></tr></table>"

}


proc year_calendar {current_year current_date {group_id 0}} {    

    set bind_vars [ad_tcl_vars_to_ns_set current_date]
    db_1row calendar_year "select
    to_char(add_months(to_date(:current_date), -12), 'YYYY-MM-DD') as prev_year,
    to_char(add_months(to_date(:current_date), 12), 'YYYY-MM-DD') as next_year
    from dual" -bind $bind_vars
    ns_set free $bind_vars

    set return_html "<table border=0 cellspcing=10 cellpadding=10>
    <tr align=center>
    <td colspan=3 bgcolor=lavender>
     <table border=0 cellspacing=0 cellpadding=0 width=100%>
     <tr align=center>
      <td>
     <a href=\"?group_id=$group_id&current_view=year&current_date=$prev_year\">
     <img border=0 src=\"/graphics/left.gif\"></a>
      <FONT face=\"Arial,Helvetica\" SIZE=+1>
      <b>
      $current_year
      </b>
      </font>
     <a href=\"?group_id=$group_id&current_view=year&current_date=$next_year\">
     <img border=0 src=\"/graphics/right.gif\"></a>
      </td>
     </tr>
     </table>
    </td>
    </tr>
    "

    set i 1
    while {$i <= 12} {
	if {[string length $i] == 1} {
	    set month "0$i"
	} else {
	    set month $i
	}

	if {[expr int(fmod([expr $i -1], 3))] == 0} {
	    if {$i != 1} {
		append return_html "</tr>"
	    }
		
	    append return_html "<tr valign=top>"
	}

	append return_html "<td>
	[mini_month_calendar $current_year $month $group_id]
	</td>
	"

	incr i
    }

    append return_html "</tr></table>"

    return $return_html	
}

###################################################
#BEGIN PROCS FOR CREATING A DAY VIEW
###################################################

#procs for a table cell object

#a cell is a list of the following items:
#root start location in table
#name
#rowspan
#colspan
#ex: {2 3} {<a href="blah.tcl">name</a>} 3 2

proc create_cell {i j text rowspan colspan } {
    return [list [list $i $j] $text $rowspan $colspan] 
}

proc cell_get_root {cell} {
    return [lindex $cell 0]
}

proc cell_get_text {cell} {
    return [lindex $cell 1]
}

proc cell_get_rowspan {cell} {
    return [lindex $cell 2]
}

proc cell_get_colspan {cell} {
    return [lindex $cell 3]
}
###
proc cell_set_root {cell i j} {
    return [lreplace $cell 0 0 [list $i $j]]
}

proc cell_set_text {cell text} {
    return [lreplace $cell 1 1 $text]
}

proc cell_set_rowspan {cell rowspan} {
    return [lreplace $cell 2 2 $rowspan]
}

proc cell_set_colspan {cell colspan} {
    return [lreplace $cell 3 3 $colspan]
}

##############################

##############################
#procs for making a table

proc create_table {{num_rows 1} {num_cols 1}} {

    if {$num_rows < 1} {
	set num_rows 1
    }

    if {$num_cols < 1} {
	set num_cols 1
    }

    set table [list]
    
    set i 0
    while {$i < $num_cols} {
	set col [list]
	set j 0
	while {$j < $num_rows} {
	    set cell [create_cell $i $j "" -1 -1]
	    
	    lappend col $cell
	    incr j
	}
	lappend table $col
	incr i
    }

    return $table
}

#i: col; j: row
proc table_get_cell {table i j} {
    return [lindex [lindex $table $i] $j]
}

proc table_set_cell {table i j cell} {
    set col [lindex $table $i]
    set col [lreplace $col $j $j $cell]
    return [lreplace $table $i $i $col]
}

proc table_add_col {table} {
    set num_cols [llength $table]
    set num_rows [llength [lindex $table 0]]

    set i 0
    set new_col [list]
    while {$i < $num_rows} {
	set cell [create_cell $num_cols $i "" 1 1]
	
	lappend new_col $cell

	incr i
    }

    return [lappend table $new_col]
}

proc table_num_cols {table} {
    return [llength $table]
}

proc table_num_rows {table} {
    return [llength [lindex $table 0]]
}

#returns the index of the first empty column in a row
#returns -1 if there is no empty column
proc table_first_empty_col {table row} {
    set num_cols [llength $table]

    set i 0
    while {$i < $num_cols} {
	set cell [table_get_cell $table $i $row]
	if {[cell_get_text $cell] == ""} {
	    return $i
	}
	incr i
    }
    
    return -1
}

proc table_next_filled_col {table row {col 0}} {
    set num_cols [llength $table]

    set i $col
    while {$i < $num_cols} {
	set cell [table_get_cell $table $i $row]
	if {[cell_get_text $cell] != ""} {
	    return $i
	}
	incr i
    }
    
    return -1
}

#returns how many columns are left to write in this row, starting with col
proc table_filled_cols_left {table row {col 0}} {
    set num_cols [llength $table]

    set return_num 0

    set i $col
    while {$i < $num_cols} {
	set cell [table_get_cell $table $i $row]
	if {![empty_string_p [cell_get_text $cell] ]} {
	    incr return_num
	}
	incr i
    }
    return $return_num
}

proc table_print_table {table} {
    set return_html "<table border=1>"
    set cols [table_num_cols $table]
    set rows [table_num_rows $table]
    set i 0
    while {$i < $rows} {
	set j 0
	append return_html "<tr>"
	while {$j < $cols} {
	    set cell [table_get_cell $table $j $i]
	    append return_html "<td nowrap><b>($j,$i)</b>$cell</td>"
	    incr j
	}
	append return_html "</tr>"
	incr i
    }
    append return_html "</table>"

    return $return_html
}

#the proc that actually returns the day view
proc day_view {current_date logged_in_user_id group_id {compress_day_view_p "f"} {begin_cal_hour 0} {end_cal_hour 23}} {
    db_1row hours_number_rows "select
    count(*) as num_hour_rows
    from calendar_hours"
    
    set table [create_table $num_hour_rows 1]

    set bind_vars [ad_tcl_vars_to_ns_set current_date logged_in_user_id group_id]
    db_foreach -bind $bind_vars calendar_relevant_info "
    select
    i.calendar_id, h.hour,
    to_char(i.end_date, 'fmHH24') as end_hour,
    to_char(i.end_date, 'fmMI') as end_minute,
    to_char(trunc(sysdate) + hour/24, 'fmHH:fmMI') || '&nbsp;' || to_char(trunc(sysdate) + hour/24, 'am') as display_hour,
    to_char(start_date, 'YYYY-MM-DD HH24:MI') as start_time,
    to_char(start_date, 'fmHH:fmMIam') as pretty_start_time,
    to_char(start_date, 'YYYY-MM') as start_year_month,
    to_char(start_date, 'Month, DD YYYY') as pretty_start_day,
    to_char(end_date, 'YYYY-MM-DD HH24:MI') as end_time,
    to_char(end_date, 'fmHH:fmMIam') as pretty_end_time,
    to_char(end_date, 'Month, DD YYYY') as pretty_end_day,
    to_char(end_date, 'YYYY-MM') as end_year_month,
    to_char(start_date) as start_date,
    to_char(end_date) as end_date,
    decode(m.user_id, NULL, 'f', 't') as user_p,
    title
    from calendar_hours h, calendar_items i, calendar_item_map m
    where end_date is not null
    and start_date(+) between 
    to_date(:current_date) + hour/24 and 
    to_date(:current_date) + (hour + 1 - 1/3600)/24
    and i.calendar_id = m.calendar_id(+)
    and (start_date is NULL
    or m.calendar_id is NULL
    or
    (:group_id = 0
    and i.calendar_id = m.calendar_id 
    and (m.user_id = :logged_in_user_id
    or m.group_id in 
    (select ugm.group_id
    from user_group_map ugm, user_group_prefs ugp
    where ugm.user_id = :logged_in_user_id
    and ugp.user_id = ugm.user_id
    and ugm.group_id = ugp.group_id
    and ugp.update_type = 'automatically')
    )
    )
    or
    (i.calendar_id = m.calendar_id
    and m.group_id = :group_id)
    )
    order by hour, start_date"  {
	#if there is a calendar item at this time...
	if {[exists_and_not_null title]} {

	    if {[string compare $start_date $end_date] == 0} {
		if {($end_minute > 0) && ($end_hour < $end_cal_hour)} {
		    set end_index [expr $end_hour + 1]
		} else {
		    set end_index $end_hour
		}
	    } else {
		set end_index 24
		#set end_index [expr $end_hour + 1]
	    }

	    #the number of rows this item takes
	    set row_span [expr $end_index - $hour]

	    #i is the row, col_index is the col

	    #find out in what table column this cell belongs
	    set col_index 0
	    #iterate through the times for this item
	    set i $hour
	    while {$i < $end_index} {
		set tmp_col_index [table_first_empty_col $table $i]

		if {$tmp_col_index == -1} {
		    #add a new column to the table--no room for
		    #this entry
		    set table [table_add_col $table]
		    set col_index [expr [table_num_cols $table] - 1]
		    break
		    
		}
		
		if {$tmp_col_index > $col_index} {
		    set col_index $tmp_col_index
		}

		incr i

	    }
	    
	    #now, actually create the table cell
	    set action "item-edit"
	    if {$start_date == $end_date} {
		set item_text "$pretty_start_time - $pretty_end_time"
	    } else {
		set item_text "$pretty_start_time - $pretty_end_day $pretty_end_time"
	    }

	    append item_text " <a href=\"?[export_url_vars action calendar_id current_date group_id]\">$title</a>"
	    
	    if {($group_id != 0) || ([string compare $user_p "t"] == 0)} {
		set grouped_link "/new-calendar/?[export_url_vars current_view current_date group_id]"
		append item_text "
		<a href=\"$grouped_link&delete_calendar_id=$calendar_id\">
		<img border=0 width=16 height=16 src=\"/graphics/trash.gif\" title= \"Delete\" alt=\"Delete\"></a>
		"
	    }
	    
	    set cell [create_cell $col_index $hour $item_text $row_span -1]
	    set i $hour

	    while {$i < $end_index} {
		set table [table_set_cell $table $col_index $i $cell]  	    
		incr i
	    }
	}
    }

    #now generate the html table
    db_1row calendar_general_html_table "
    select
    to_char(to_date(:current_date), 'fmDay fmMonth, fmDD YYYY') as pretty_current_day,
    to_date(:current_date) - 1 as previous_day,
    to_date(:current_date) + 1 as next_day
    from dual
    " -bind $bind_vars

    set return_html "
    <table cellpadding=2 cellspacing=0 border=0  width=90%>
    <tr>
    <td>
    <table cellpadding=3 cellspacing=0 border=0 width=\"100%\">
    <tr bgcolor=lavender>
    <td align=center>
    <a href=\"?group_id=$group_id&current_view=day&current_date=$previous_day\">
    <img border=0 src=\"/graphics/left.gif\"></a>
    <FONT face=\"Arial,Helvetica\" SIZE=+1>
    <B>
    $pretty_current_day
    </B>
    </FONT>
    <a href=\"?group_id=$group_id&current_view=day&current_date=$next_day\">
    <img border=0 src=\"/graphics/right.gif\"></a>
    </td>
    </tr>
    </table>
    </TD>
    </TR>
    <tr>
    <td>
    <table border=1 cellpadding=2 cellspacing=0 width=100%>
    "

    #add all-day items first
    set num_cols [table_num_cols $table]
    set all_day_html "
    <tr>
     <td valign=top nowrap width=10%>
    <a href=\"?current_view=day&current_date=$current_date&start_date=$current_date%2000:00&end_date=&action=item-add\">All Day</a>
    </td>
    "

    set all_day_itmes "
    <ul>"
    set count 0

    db_foreach -bind $bind_vars calendar_all_day_items "
    select
    i.calendar_id,
    decode(m.user_id, NULL, 'f', 't') as user_p,
    title,
    upper(title)
    from calendar_items i, calendar_item_map m
    where start_date =  to_date(:current_date)
    and i.calendar_id = m.calendar_id(+)
    and (end_date is NULL
       and
        ((:group_id = 0
         and i.calendar_id = m.calendar_id 
         and (m.user_id = :logged_in_user_id
           or m.group_id in 
            (select ugm.group_id
             from user_group_map ugm, user_group_prefs ugp
             where ugm.user_id = :logged_in_user_id
             and ugp.user_id = ugm.user_id
             and ugm.group_id = ugp.group_id
             and ugp.update_type = 'automatically'
            )
          )
        )
        or
        (i.calendar_id = m.calendar_id
         and m.group_id = :group_id)
        ))
    order by upper(title)" {
	append all_day_items "<li>
	<a href=\"?action=item-edit&calendar_id=$calendar_id&current_view=day&current_date=$current_date\">$title</a>"

	if {($group_id != 0) || ([string compare $user_p "t"] == 0)} {
	    set grouped_link "/new-calendar/?[export_url_vars current_view current_date group_id]"
	    append all_day_items "
	    <a href=\"$grouped_link&delete_calendar_id=$calendar_id\">
	    <img border=0 width=16 height=16 src=\"/graphics/trash.gif\" title=\"Delete\" alt=\"Delete\"></a>
	    "
	}
	incr count
    }

    set colspan [table_num_cols $table]
    if {$count > 0} {
	append all_day_html "<td colspan=$colspan>$all_day_items </ul>"
    } else {
	append all_day_html "<td bgcolor=\"DCDCDC\" colspan=$colspan>&nbsp;"
    }
    append all_day_html "</td></tr>"    

    if {([string compare $compress_day_view_p "f"] == 0) || (([string compare $compress_day_view_p "t"] == 0) && ($count > 0))} {
	append return_html $all_day_html
    }

    set i 0
    while {$i < $num_hour_rows} {
	set filled_cell_count 0
	set row_html ""
	set bgcolor_html ""
	if {$i < 12} {
	    if {$i == 0} {
		set time "12:00 am"
	    } else {
		set time "$i:00 am"
	    }
	} else {
	    if {$i == 12} {
		set time "12:00 pm"
		set bgcolor_html "bgcolor=\"FFF8DC\""
	    } else {
		set time "[expr $i - 12]:00 pm"
	    }	 
	}

	if {$i < 10} {
	    set fm_hour "0$i"
	} else {
	    set fm_hour "$i"
	}
	    
	set encoded_start_time "$current_date $fm_hour:00"

	append row_html "
	<tr>
	<td valign=top nowrap $bgcolor_html width=10%>
	<a href=\"?current_view=day&current_date=$current_date&start_date=$encoded_start_time&action=item-add\">
	$time</a></td>
	"

	set j 0
	set total_cols 0
	while {$j < $num_cols} {
	    set cell [table_get_cell $table $j $i]
	    set cell_text [cell_get_text $cell]
	    
	    #need to check if there is room for this empty cell
	    set filled_left [table_filled_cols_left $table $i $j] 
	    set filled_check [expr $num_cols - $filled_left - $total_cols]

	    #see if we need to write an empty table cell
	    if {[empty_string_p $cell_text] && ($filled_check >0)} {
		#this cell is empty, so we may write an empty tag
		
		#see how long to make the colspan for this cell
		set filled_index [table_next_filled_col $table $i $j]
		if {$filled_index == -1} {
		    set colspan [expr $num_cols - $j]
		} else {
		    set colspan [expr abs($j - $filled_index)]
		}

		if {$colspan > 0} {
		    append row_html "<td colspan=$colspan bgcolor=\"DCDCDC\">&nbsp;</td>"
		    set total_cols [expr $total_cols + $colspan]
		}
	    }

	    #see if we write the contents of this cell
	    set cell_root [cell_get_root $cell]
	    if {![empty_string_p $cell_text]} {
		incr filled_cell_count
		
		#get the rowspan
		set rowspan [cell_get_rowspan $cell]
		
		#see how long to make the colspan for this cell

		#start at the root row
		set k [lindex [cell_get_root $cell] 1]
		#go until this cell ends
		set cell_end_row [expr $k + [cell_get_rowspan $cell]]
		set filled_index [table_num_cols $table]
		while {$k < $cell_end_row} {
		    set tmp_filled_index [table_next_filled_col $table $k [expr $j + 1]]
		    if {($tmp_filled_index < $filled_index) && ($tmp_filled_index != -1)} {
			set filled_index $tmp_filled_index
		    }
		    incr k
		}

		if {$filled_index == -1} {
		    set colspan [expr $num_cols - $j]
		} else {
		    set colspan [expr $filled_index - $j]
		}

		#this is the root cell, so write its contents
		if {([lindex $cell_root 0] == $j) && ([lindex $cell_root 1] == $i)} {
		    append row_html "
		    <td valign=top rowspan=$rowspan colspan=$colspan>
		    $cell_text
		    </td>\n"	
		}

		set total_cols [expr $total_cols + $colspan]
	    }
	    incr j
	}
	append row_html "</tr>"
	
	if {($filled_cell_count > 0) || (([string compare $compress_day_view_p "f"] == 0) && ($i >= $begin_cal_hour) && ($i <= $end_cal_hour))} {
	    append return_html $row_html
	} 



	incr i    
    }


    append return_html "
    </table>\n
    </td>\n</tr>\n
    </table>"

    ns_set free $bind_vars

    return $return_html
}
