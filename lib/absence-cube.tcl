
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

im_absence_component__timescale \
    -num_daysVar num_days \
    -start_dateVar start_date \
    -end_dateVar end_date \
    -timescale_date $timescale_date \
    -timescale $timescale

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

set where_clause ""

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

# Initialize the hash for holidays.
array set holiday_hash {}

set sql "select to_char(to_date(:start_date,:date_format) + interval '$num_days days', :date_format)"
set absence_week_days \
    [im_absence_week_days \
        -start_date $start_date \
        -end_date [db_string end_date $sql]]

foreach weekend_date $absence_week_days {
    set holiday_hash($weekend_date) 5
}
set day_list \
    [im_absence_day_list \
        -date_format $date_format \
        -num_days $num_days \
        -start_date $start_date]

# ---------------------------------------------------------------
# Determine Left Dimension
# ---------------------------------------------------------------

set user_list [db_list_of_lists user_list "
    select	u.user_id as user_id,
    im_name_from_user_id(u.user_id, $name_order) as user_name
    from	users u,
    cc_users cc
    where	u.user_id in (
      -- Individual Absences per user
      select	a.owner_id
      from	im_user_absences a,
            users u
      where	a.owner_id = u.user_id and
            a.start_date <= :end_date::date and
            a.end_date >= :start_date::date
            $where_clause
      UNION
      -- Absences for user groups
      select	mm.member_id as owner_id
      from	im_user_absences a,
            users u,
      group_distinct_member_map mm
      where	mm.member_id = u.user_id and
            a.start_date <= :end_date::date and
            a.end_date >= :start_date::date and
            mm.group_id = a.group_id
            $where_clause
    )
    and cc.member_state = 'approved'
    and cc.user_id = u.user_id
    order by
    lower(im_name_from_user_id(u.user_id, $name_order))
"]


# Get list of category_ids to determine index 
# needed for color codes

set sql "
    select  category_id
    from    im_categories
    where   category_type = 'Intranet Absence Type'
    order by category_id
"

set category_list [list]
db_foreach category_id $sql {
    lappend category_list [list $category_id]
}

# ---------------------------------------------------------------
# Get individual absences
# ---------------------------------------------------------------

array set absence_hash {}
set absence_sql "
    -- Individual Absences per user
    select	a.absence_type_id,
            a.owner_id,
            d.d
    from	im_user_absences a,
            users u,
            (select im_day_enumerator as d from im_day_enumerator(:start_date, :end_date)) d,
            cc_users cc
    where	a.owner_id = u.user_id and
            cc.user_id = u.user_id and 
            cc.member_state = 'approved' and
            a.start_date <= :end_date::date and
            a.end_date >= :start_date::date and
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
            (select im_day_enumerator as d from im_day_enumerator(:start_date, :end_date)) d
    where	mm.member_id = u.user_id and
            a.start_date <= :end_date::date and
            a.end_date >= :start_date::date and
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
            (select im_day_enumerator as d from im_day_enumerator(:start_date, :end_date)) d
    where	mm.member_id = u.user_id and
            a.start_date <= :end_date::date and
            a.end_date >= :start_date::date and
            date_trunc('day',d.d) between date_trunc('day',a.start_date) and date_trunc('day',a.end_date) and 
            mm.group_id = a.group_id and
            a.absence_type_id in ([template::util::tcl_to_sql_list [im_sub_categories [im_user_absence_type_bank_holiday]]]) and
            a.absence_status_id in ([template::util::tcl_to_sql_list [im_sub_categories [im_user_absence_status_active]]])
"

# TODO: re-factor so that color codes also work in case of more than 10 absence types
db_foreach absences $absence_sql {
    set key "$owner_id-$d"
    set value [get_value_if absence_hash(${key}) ""]
    set absence_hash($key) [append value [lsearch $category_list $absence_type_id]]
}

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

        set value [get_value_if absence_hash(${key}) ""]

        if {[info exists holiday_hash($date_date)]} { 
            append value $holiday_hash($date_date) 
        }
        if {$hide_colors_p && $value != "" } {
            set value "1"
        }
        append table_body [im_absence_cube_render_cell $value]
        ns_log debug "intranet-absences-procs::im_absence_cube_render_cell: $value"
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

