#   absence-calendar.tcl
#
#   Displays a yearly calendar of absences for a user. 
#   Uses the same color coding as the absence cube, but
#   instead of displaying multiple users, it works only 
#   for one user.
#
#    user_selection
#    year:integer,notnull

# Get list of absence types to determine index 
# needed for color codes

set sql "
    select  category_id,category
    from    im_categories
    where   category_type = 'Intranet Absence Type'
    and enabled_p = 't'
    order by category_id
"

set category_list [list]
set absence_types [list]
db_foreach absence_types $sql {
    lappend absence_types [list $category_id $category]
    lappend category_list [list $category_id]
}

# ---------------------------------------------------------------
# Get individual absences
# ---------------------------------------------------------------

set leap_year_p [expr ( $year % 4 == 0 ) && ( ( $year % 100 != 0 ) || ( $year % 400 == 0 ) )]
set num_days [ad_decode $leap_year_p t 366 365]
set report_start_date "${year}-01-01"
set report_end_date "${year}-12-31"

im_absence_component__user_selection \
    -where_clauseVar where_clause \
    -user_selection $user_selection \
    -hide_colors_pVar hide_colors_p

set absence_sql "
    -- Individual Absences per user
    select	a.absence_type_id,
            a.owner_id,
            d.d
    from	im_user_absences a,
            users u,
            (select im_day_enumerator as d from im_day_enumerator(:report_start_date, :report_end_date)) d,
            cc_users cc
    where	a.owner_id = u.user_id and
            cc.user_id = u.user_id and 
            cc.member_state = 'approved' and
            a.start_date <= :report_end_date::date and
            a.end_date >= :report_start_date::date and
            date_trunc('day',d.d) between date_trunc('day',a.start_date) and date_trunc('day',a.end_date) 
            $where_clause
    UNION
    -- Absences for user groups
    select	a.absence_type_id,
            mm.member_id as owner_id,
            d.d
    from	im_user_absences a,
            users u,
            group_distinct_member_map mm,
            (select im_day_enumerator as d from im_day_enumerator(:report_start_date, :report_end_date)) d
    where	mm.member_id = u.user_id and
            a.start_date <= :report_end_date::date and
            a.end_date >= :report_start_date::date and
            date_trunc('day',d.d) between date_trunc('day',a.start_date) and date_trunc('day',a.end_date) and 
            mm.group_id = a.group_id
            $where_clause
    UNION
    -- Absences for bridge days
    select	a.absence_type_id,
            mm.member_id as owner_id,
            d.d
    from	im_user_absences a,
            users u,
            group_distinct_member_map mm,
            (select im_day_enumerator as d from im_day_enumerator(:report_start_date, :report_end_date)) d
    where	mm.member_id = u.user_id and
            a.start_date <= :report_end_date::date and
            a.end_date >= :report_start_date::date and
            date_trunc('day',d.d) between date_trunc('day',a.start_date) and date_trunc('day',a.end_date) and 
            mm.group_id = a.group_id and
            a.absence_type_id in ([template::util::tcl_to_sql_list [im_sub_categories [im_user_absence_type_bank_holiday]]]) and
            a.absence_status_id in ([template::util::tcl_to_sql_list [im_sub_categories [im_user_absence_status_active]]])
"


# TODO: re-factor so that color codes also work in case of more than 10 absence types
array set absence_hash [list]
db_foreach absences $absence_sql {
    set date_date ${d}
    set key ${date_date}
    set value [get_value_if absence_hash(${key}) ""]
    set index [lsearch $category_list $absence_type_id]
    set absence_hash($key) [append value $index]
}

set weekend_days \
    [im_absence_week_days \
        -start_date $report_start_date \
        -end_date $report_end_date]

foreach weekend_date $weekend_days {
    append absence_hash($weekend_date) 5
}


# ---------------------------------------------------------------
# Render the table
# ---------------------------------------------------------------

set bgcolor(0) " class=roweven "
set bgcolor(1) " class=rowodd "

set table_header "<tr class=rowtitle>\n"
append table_header "<td class=rowtitle>${year}</td>\n"
for {set day_num 1} {$day_num <= 31} {incr day_num} {
    set day_num_padded [format "%.2d" $day_num]
    append table_header "<td class=rowtitle>$day_num_padded</td>\n"
}

append table_header "</tr>\n"
set row_ctr 0
set table_body ""
for {set month_num 1} {$month_num <= 12} {incr month_num} {

    set num_days_in_month [dt_num_days_in_month $year $month_num]

    set month_num_padded [format "%.2d" $month_num]

    set month_name [lc_time_fmt ${year}-${month_num}-01 "%B"]

    append table_body "<tr $bgcolor([expr $row_ctr % 2])>\n"
    append table_body "<td><nobr>$month_name</td></nobr>\n"
    for {set day_num 1} {$day_num <= 31} {incr day_num} {

        set day_num_padded [format "%.2d" $day_num]

        set date_date "${year}-${month_num_padded}-${day_num_padded}"

        set key ${date_date}

        set value [get_value_if absence_hash(${key}) ""]

        if {$hide_colors_p && $value != "" } {
            set value "1"
        }

        if {$day_num > $num_days_in_month} {
            set value "9"
        }

        append table_body [im_absence_cube_render_cell $value]
        ns_log debug "intranet-absences-procs::im_absence_cube_render_cell: $value"
    }
    append table_body "</tr>\n"
    incr row_ctr
}

set absence_types_table ""
if { !${hide_explanation_p} && !${hide_colors_p} } {
    set row_ctr 0
    append absence_types_table "<table style=\"width:75px;\">"
    foreach absence_type_tuple $absence_types {
        foreach {absence_type_id absence_type} $absence_type_tuple break

        set color [im_absence_mix_colors $row_ctr]

        append absence_types_table "<tr>"
        append absence_types_table "<td bgcolor=\"\#${color}\">${absence_type}</td>"
        append absence_types_table "</tr>"
        incr row_ctr
    }
    append absence_types_table "</table>"
}

set table "
<table>
  <tr>
    <td>
      <table>
      $table_header
      $table_body
      </table>
    </td>
    <td valign=\"top\">${absence_types_table}</td>
  </tr>
</table>
"

