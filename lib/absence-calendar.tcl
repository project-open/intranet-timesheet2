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

set absence_types [im_absence_types]
array set indexof [list]
set index -1
foreach absence_type $absence_types {
    foreach {category_id category enabled_p bg_color fg_color} $absence_type break
    set indexof($category_id) [incr index]
}

# ---------------------------------------------------------------
# Get individual absences
# ---------------------------------------------------------------

set leap_year_p [expr ( $year % 4 == 0 ) && ( ( $year % 100 != 0 ) || ( $year % 400 == 0 ) )]
set num_days [ad_decode $leap_year_p t 366 365]
set report_start_date "${year}-01-01"
set report_end_date "${year}-12-31"

im_absence_component__absence_criteria \
    -where_clauseVar where_clause \
    -user_selection $user_selection \
    -absence_type_id $absence_type_id \
    -absence_status_id $absence_status_id

im_absence_component__user_selection \
    -where_clauseVar where_clause \
    -user_selection $user_selection \
    -user_selection_typeVar user_selection_type \
    -total_countVar total_count \
    -is_aggregate_pVar is_aggregate_p \
    -hide_colors_pVar hide_colors_p

set absences_sql "
    -- Individual Absences per user
    select	a.absence_type_id,
            a.absence_status_id,
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
            a.absence_status_id,
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
            a.absence_status_id,
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

array set is_req_category_p [list]
set req_categories [im_sub_categories [im_user_absence_status_requested]]
foreach category_id $req_categories { 
    set is_req_category_p($category_id) 1
}

array set absence_hash [list]
array set cell_char [list]
db_foreach absences $absences_sql {
    set date_date ${d}
    set key ${date_date}
    set index $indexof($absence_type_id)
    lappend absence_hash($key) $index

    if { [get_value_if is_req_category_p($absence_status_id) "0"] } {
        set cell_char($key) "?"
    }
}

set weekend_days \
    [im_absence_week_days \
        -start_date $report_start_date \
        -end_date $report_end_date]

# we mark each weekend with the bank_holiday_index but we also
# use the bank_holiday_index to exclude weekends from aggregate
# results (so that we won't show everyone absent on weekends 
# and bank holidays
set bank_holiday_absence_type_id [im_user_absence_type_bank_holiday]
set bank_holiday_index $indexof($bank_holiday_absence_type_id)
foreach weekend_date $weekend_days {
    set cell_char($weekend_date) "&nbsp;"
    lappend absence_hash($weekend_date) $bank_holiday_index
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

# other absences is used as the default type when
# showing aggregate results like say in a project
set other_absences_type_id [im_user_absence_type_personal]
set index $indexof($other_absences_type_id)
foreach {_category_id _category _dummy_enabled_p other_bg_color other_fg_color} \
    [lindex $absence_types $index] break

set extra_style ""
set table_style ""
if { $is_aggregate_p } {

    # if we are going to show percentages, 
    # we need bigger boxes and better have
    # all boxes show the same width
    set extra_style "padding:0px;margin:0px;font-size:10px;"

    # if we show month abbreviations we can set the
    # whole table to a fixed layout (which means it
    # won't resize from project to project and cost center
    # to cost center depending on the computed percentages)
    #
    # set table_style "width:100%;table-layout:fixed;"

}


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

        set day_absence_types [get_value_if absence_hash(${key}) ""] 
        set index [lindex $day_absence_types end]
        set cell_str [get_value_if cell_char(${key}) "&nbsp;"]

        if { $index ne {} } {
            if {$index ne $bank_holiday_index && ($hide_colors_p || $is_aggregate_p) } {
                # Expected behavior When trying to view the absence for one project as a project manager
                # is to see all days marked with "other absence" where at least one employee from the
                # project is absent. The value of the field should not be empty but equal the percentage
                # of employees not present, so 100 = everyone in the team is gone.
                set bg_color $other_bg_color
                set fg_color $other_fg_color

                if { $total_count ne {} } {
                    set count [llength [lsearch -inline -all -not $day_absence_types $bank_holiday_index]]
                    set decimal [expr { double(${count}) / ${total_count} }]
                    if { ${decimal} == 0 } {
                        set cell_str "&nbsp;"
                    } else {
                        if { ${decimal} == 1 } {
                            set cell_str "100%"
                        } else {
                            set percent [expr { 100.0 * ${decimal} }]
                            set cell_str "[format "%.0f" ${percent}]%"
                            # set cell_str "[llength $day_absence_types]/${total_count}"
                        }
                    }
                }

            } else {
                if { $index eq $bank_holiday_index && $is_aggregate_p } {
                    set cell_str "&nbsp;"
                }
                foreach {category_id category enabled_p bg_color fg_color} \
                    [lindex $absence_types $index] break
            }
        } else {
            set bg_color "#fff"
            set fg_color "#fff"
        }


        if {$day_num > $num_days_in_month} {
            set bg_color "#ccc"
            set fg_color "#ccc"
        }

        append table_body [im_absence_render_cell $bg_color $fg_color $cell_str "center" ${extra_style}]

    }
    append table_body "</tr>\n"
    incr row_ctr
}

set absence_types_table ""
if { !${hide_explanation_p} && !${hide_colors_p} } {
    set absence_types_table [im_absence_cube_legend]
}

set table "
<table>
  <tr>
    <td>
      <table style=\"${table_style}\">
      $table_header
      $table_body
      </table>
    </td>
    <td valign=\"top\">${absence_types_table}</td>
  </tr>
</table>
"

