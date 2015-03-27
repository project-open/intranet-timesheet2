
#ad_page_contract {
#    Returns a rendered cube with a graphical absence display
#    for users.
#} {
#    {-absence_status_id "" }
#    {-absence_type_id "" }
#    {-user_selection "" }
#    {-timescale "" }
#    {-timescale_date "" }
#    {-user_id_from_search "" }
#    {-user_id ""}
#    {-cost_center_id ""}
#    {-hide_colors_p 0}
#    {-project_id ""}
#}


set current_user_id [ad_get_user_id]
set view_absences_all_p [im_permission $current_user_id "view_absences_all"]

# Fix some timescales

switch $timescale {
    future {set timescale next_3m}
    past {set timescale last_3m}
    all {set timescale last_3m}
    today {set timescale next_3w}
}

set where_clause ""

im_absence_component__timescale \
    -num_daysVar num_days \
    -start_dateVar start_date \
    -end_dateVar end_date \
    -timescale_date $timescale_date \
    -timescale $timescale \
    -where_clauseVar where_clause

set html ""

if {$num_days eq {}} {
    set html [lang::message::lookup "" intranet-timesheet2.AbsenceCubeNotShownAllAbsences \
        "Graphical view of absences not available for Timescale option '${timescale}'. Please choose a different option."]
    return
}

# absence cube expects a positive number for num_days
# the rest of the absences components do not have such
# restrictions
if {$num_days < 0 } {
    set num_days [expr { abs($num_days) }]
}
     
if {$num_days > 370} {
    set html [lang::message::lookup "" intranet-timesheet2.AbsenceCubeNotShownGreateOneYear \
        "Graphical view of absences only available for periods less than 1 year"]
    return
}


set user_url "/intranet/users/view"
set date_format "YYYY-MM-DD"
set bgcolor(0) " class=roweven "
set bgcolor(1) " class=rowodd "
set name_order [parameter::get -package_id [apm_package_id_from_key intranet-core] -parameter "NameOrder" -default 1]

# ---------------------------------------------------------------
# Generate SQL
# ---------------------------------------------------------------


im_absence_component__absence_criteria \
    -where_clauseVar where_clause \
    -user_selection $user_selection \
    -absence_type_id $absence_type_id \
    -absence_status_id $absence_status_id

im_absence_component__user_selection \
    -where_clauseVar where_clause \
    -user_selection $user_selection \
    -hide_colors_pVar hide_colors_p

# ---------------------------------------------------------------
# Determine Top Dimension
# ---------------------------------------------------------------

set day_list \
    [im_absence_day_list \
        -date_format $date_format \
        -num_days $num_days \
        -start_date $start_date]

# ---------------------------------------------------------------
# Determine Left Dimension
# ---------------------------------------------------------------

set user_list [db_list_of_lists user_list "
    select	user_id,
            im_name_from_user_id(user_id, $name_order) as user_name
    from	cc_users u
    where	u.user_id in (
              [ad_decode $user_selection {mine} {select :current_user_id from dual UNION} {}]
              -- Individual Absences per user
              select	a.owner_id
              from	users u inner join im_user_absences a on (a.owner_id=u.user_id)
              where	1=1
                    $where_clause
              UNION
              -- Absences for user groups
              select	mm.member_id as owner_id
              from	users u inner join im_user_absences a on (a.owner_id=u.user_id),
                    group_distinct_member_map mm
              where	mm.member_id = u.user_id and
                    mm.group_id = a.group_id
                    $where_clause
            )
    and u.member_state = 'approved'
    order by
    lower(im_name_from_user_id(u.user_id, $name_order))
"]


# ---------------------------------------------------------------
# Get individual absences
# ---------------------------------------------------------------

array set absence_hash {}
set absence_sql "
    -- Individual Absences per user
    select	a.absence_type_id,
            a.absence_status_id,
            a.owner_id,
            d.d
      from  cc_users u inner join im_user_absences a on (a.owner_id=u.user_id),
            (select im_day_enumerator as d from im_day_enumerator(:start_date, :end_date)) d
    where   u.member_state = 'approved' and
            date_trunc('day',d.d) between date_trunc('day',a.start_date) and date_trunc('day',a.end_date) 
            $where_clause
    UNION
    -- Absences for user groups
    select	a.absence_type_id,
            a.absence_status_id,
            mm.member_id as owner_id,
            d.d
    from    users u inner join im_user_absences a on (a.owner_id=u.user_id),
            group_distinct_member_map mm,
            (select im_day_enumerator as d from im_day_enumerator(:start_date, :end_date)) d
    where	mm.member_id = u.user_id and
            date_trunc('day',d.d) between date_trunc('day',a.start_date) and date_trunc('day',a.end_date) and 
            mm.group_id = a.group_id
            $where_clause
"

# Get list of category_ids to determine index 
# needed for color codes

set absence_types [im_absence_types]
array set indexof [list]
set index -1
foreach absence_type $absence_types {
    foreach {category_id category enabled_p bg_color fg_color} $absence_type break
    set indexof($category_id) [incr index]
}

db_foreach absences $absence_sql {
    set key "$owner_id-$d"
    lappend absence_hash($key) $indexof($absence_type_id)
    
    if {[lsearch [im_sub_categories [im_user_absence_status_requested]] $absence_status_id]>-1} {
        set cell_char($key) "?"
    }
}

set sql "select to_char(to_date(:start_date,:date_format) + interval '$num_days days', :date_format)"
set end_date  [db_string end_date $sql]
set weekend_days \
    [im_absence_week_days \
        -start_date $start_date \
        -end_date $end_date]

# we mark each weekend with the bank_holiday_index but we also
# use the bank_holiday_index to exclude weekends from aggregate
# results (so that we won't show everyone absent on weekends 
# and bank holidays
set weekend_absence_type_id [im_user_absence_type_weekend]
set weekend_index $indexof($weekend_absence_type_id)
foreach weekend_date $weekend_days {
    set cell_char($weekend_date) "&nbsp;"
    set holiday_hash($weekend_date) $weekend_index
}

# ---------------------------------------------------------------
# Add bank holidays
# ---------------------------------------------------------------
set bank_holiday_ids [im_sub_categories [im_user_absence_type_bank_holiday]] 
set bank_holiday_indexes [list]
foreach bank_holiday_absence_type_id $bank_holiday_ids {
    set bank_holidays [im_absence_dates -absence_type_ids $bank_holiday_absence_type_id \
        -start_date $start_date \
        -end_date $end_date
    ]
    lappend bank_holiday_indexes $indexof($bank_holiday_absence_type_id)
    foreach bank_date $bank_holidays {
        set cell_char($bank_date) "&nbsp;"
        set holiday_hash($bank_date) $indexof($bank_holiday_absence_type_id)
    }
}


# other absences is used as the default type when
# showing aggregate results like say in a project
set other_absences_type_id [im_user_absence_type_personal]
set index $indexof($other_absences_type_id)
foreach {_category_id _category _dummy_enabled_p other_bg_color other_fg_color} \
    [lindex $absence_types $index] break

set extra_style ""
set table_style ""

# ---------------------------------------------------------------
# Render the table
# ---------------------------------------------------------------

set table_header "<tr class=rowtitle>\n"
append table_header "<td class=rowtitle>[_ intranet-core.User]</td>\n"
foreach day $day_list {
    set date_date [lindex $day 0]
    set date_day_of_month [lindex $day 1]
    set date_month_of_year [lindex $day 2]
    set date_year [lindex $day 3]
    append table_header "<td class=rowtitle>$date_month_of_year<br>$date_day_of_month</td>\n"
}

append table_header "</tr>\n"
set row_ctr 0
set table_body ""
foreach user_tuple $user_list {
    append table_body "<tr $bgcolor([expr $row_ctr % 2])>\n"
    set user_id [lindex $user_tuple 0]
    set user_name [lindex $user_tuple 1]
    append table_body "<td><nobr><a href='[export_vars -base $user_url {user_id}]'>$user_name</a></td></nobr>\n"
    foreach day $day_list {
        set date_date [lindex $day 0]
        set key "$user_id-$date_date"

        set day_absence_types [get_value_if absence_hash(${key}) ""] 
        if { [info exists holiday_hash(${date_date})] } {
            set index $holiday_hash($date_date)
        } else {
            set index [lindex $day_absence_types end]
        }
        set cell_str [get_value_if cell_char(${key}) "&nbsp;"]

        if { $index ne {} } {
            if { [lsearch $bank_holiday_indexes $index]<0 && $hide_colors_p } {
                # Expected behavior When trying to view the absence for one project as a project manager
                # is to see all days marked with "other absence" where at least one employee from the
                # project is absent. The value of the field should not be empty but equal the percentage
                # of employees not present, so 100 = everyone in the team is gone.
                set bg_color $other_bg_color
                set fg_color $other_fg_color
            } else {
                foreach {category_id category enabled_p bg_color fg_color} \
                    [lindex $absence_types $index] break
            }
        } else {
            set bg_color "#fff"
            set fg_color "#fff"
        }
        append table_body [im_absence_render_cell $bg_color $fg_color $cell_str "center" ${extra_style}]
        ns_log debug "intranet-absences-procs::im_absence_cube_render_cell: $index"
    }
    append table_body "</tr>\n"
    incr row_ctr
}

set html "
<table>
$table_header
$table_body
</table>
"

